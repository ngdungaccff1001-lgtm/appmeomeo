import os
import json
import uuid
import time
import random
import string
import urllib.request
import urllib.parse
import re
from flask import Flask, render_template, request, jsonify, send_from_directory, redirect
from werkzeug.utils import secure_filename

app = Flask(__name__)
app.config['SECRET_KEY'] = 'meomeopath-admin-secret-2026'

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
UPLOAD_FOLDER = os.path.join(BASE_DIR, 'uploads')
PATCHES_FILE = os.path.join(BASE_DIR, 'patches.json')
KEYS_FILE = os.path.join(BASE_DIR, 'keys.json')
SETTINGS_FILE = os.path.join(BASE_DIR, 'settings.json')
TOKENS_FILE = os.path.join(BASE_DIR, 'tokens.json')
CLAIMS_FILE = os.path.join(BASE_DIR, 'claims.json')

os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# MARK: - Data Storage Helpers

def load_json(filepath, default_value):
    if os.path.exists(filepath):
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception:
            return default_value
    return default_value

def save_json(filepath, data):
    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

def get_settings():
    default_settings = {
        "server_online": True,
        "emergency_mode": False,
        "emergency_message": "Máy chủ đang bảo trì nâng cấp hệ thống!",
        "emergency_link_title": "LIÊN HỆ TELEGRAM",
        "emergency_link_url": "https://t.me/ioscrackvn",
        "default_app_name": "MeoMeoPath",
        "default_welcome_title": "CHÀO MỪNG ĐẾN APIMEOMEO",
        "default_welcome_subtitle": "Hệ thống Mod & Patch Tối Ưu Game Free Fire Chuyên Nghiệp"
    }
    return load_json(SETTINGS_FILE, default_settings)

def generate_key_string():
    part1 = ''.join(random.choices(string.ascii_uppercase + string.digits, k=4))
    part2 = ''.join(random.choices(string.ascii_uppercase + string.digits, k=4))
    part3 = ''.join(random.choices(string.ascii_uppercase + string.digits, k=4))
    return f"MEOMEO-{part1}-{part2}-{part3}"

def generate_seller_token():
    part = ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))
    return f"SELLER-{part}"

# MARK: - 3-Tier Shortlink Chain (Ontops -> Layma -> Layma -> Claim)

def shorten_layma(target_url):
    layma_token = "77e5a6f69bfddbdb298b37f3783007e8"
    encoded_url = urllib.parse.quote(target_url, safe='')
    api_url = f"https://api.layma.net/api/admin/shortlink/quicklink?tokenUser={layma_token}&url={encoded_url}"

    try:
        req = urllib.request.Request(api_url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=5) as response:
            res_data = response.read().decode('utf-8')
            try:
                res_json = json.loads(res_data)
                shortlink = res_json.get('shortlink') or res_json.get('shortenedUrl') or res_json.get('url')
                if shortlink:
                    return shortlink
            except Exception:
                pass
            urls = re.findall(r'https?://[^\s"\'<>]+', res_data)
            if urls:
                return urls[0]
    except Exception as e:
        print(f"[Layma API Error] {e}")
    return target_url

def shorten_ontops(target_url):
    ontops_key = "0f2c5d281a2e42a19c28919242544e23"
    encoded_url = urllib.parse.quote(target_url, safe='')
    api_url = f"http://ontops.link/st?apikey={ontops_key}&url={encoded_url}"

    try:
        req = urllib.request.Request(api_url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=5) as response:
            res_data = response.read().decode('utf-8')
            try:
                res_json = json.loads(res_data)
                shortlink = res_json.get('shortlink') or res_json.get('url')
                if shortlink:
                    return shortlink
            except Exception:
                pass
            urls = re.findall(r'https?://[^\s"\'<>]+', res_data)
            if urls:
                return urls[0]
    except Exception as e:
        print(f"[Ontops API Error] {e}")
    return target_url

def get_3tier_shortlink(claim_url):
    # Lớp 3 (Trong cùng): Rút gọn Claim URL qua Layma lần 2
    layma_url_2 = shorten_layma(claim_url)
    # Lớp 2 (Giữa): Rút gọn qua Layma lần 1
    layma_url_1 = shorten_layma(layma_url_2)
    # Lớp 1 (Ngoài cùng): Rút gọn qua Ontops
    ontops_url = shorten_ontops(layma_url_1)
    return ontops_url

# MARK: - Public & Admin Routes

@app.route('/')
def index():
    return render_template('403.html'), 403

@app.route('/nxt2007')
def admin_panel():
    patches = load_json(PATCHES_FILE, [])
    keys = load_json(KEYS_FILE, [])
    tokens = load_json(TOKENS_FILE, [])
    settings = get_settings()

    current_time = time.time()
    for k in keys:
        if k.get('expires_at') and k.get('expires_at') < current_time and k.get('status') == 'active':
            k['status'] = 'expired'
        if k.get('expires_at'):
            k['expires_at_str'] = time.strftime("%Y-%m-%d %H:%M", time.localtime(k['expires_at']))

    save_json(KEYS_FILE, keys)
    return render_template('admin.html', patches=patches, keys=keys, tokens=tokens, settings=settings)

# MARK: - Seller Web Portal (/seller/<token> & /seller<token>)

@app.route('/seller/<token_str>')
@app.route('/seller<token_str>')
def seller_portal(token_str):
    tokens = load_json(TOKENS_FILE, [])
    matched = None
    clean_token = token_str.strip().upper()

    for t in tokens:
        if t.get('token', '').upper() == clean_token:
            matched = t
            break

    if not matched:
        return "<h3>Không tìm thấy Seller Token này. Vui lòng liên hệ Admin để nhận link!</h3>", 404

    keys = load_json(KEYS_FILE, [])
    current_time = time.time()
    seller_keys = []

    for k in keys:
        if k.get('seller_token', '').upper() == clean_token or f"[Seller: {clean_token}]" in k.get('note', ''):
            if k.get('expires_at') and k.get('expires_at') < current_time and k.get('status') == 'active':
                k['status'] = 'expired'
            if k.get('expires_at'):
                k['expires_at_str'] = time.strftime("%Y-%m-%d %H:%M", time.localtime(k['expires_at']))
            seller_keys.append(k)

    return render_template('seller.html', token=matched, keys=seller_keys)

# MARK: - 12H Key Generator via 3-Tier Shortlinks (/getkey & /getkey/claim)

@app.route('/getkey')
def get_key_landing():
    hwid = request.args.get('hwid', '').strip()
    client_ip = request.headers.get('X-Forwarded-For', request.remote_addr)

    keys = load_json(KEYS_FILE, [])
    now = time.time()

    # Kiểm tra xem HWID/IP có key 12h còn hạn không
    existing_active_key = None
    if hwid:
        for k in keys:
            if k.get('duration_days') == 0.5 and k.get('expires_at') and k.get('expires_at') > now:
                for d in k.get('bound_hwids', []):
                    if d.get('hwid') == hwid:
                        existing_active_key = k.get('key')
                        break

    # Tạo One-Time Claim Session
    claims = load_json(CLAIMS_FILE, [])
    # Dọn dẹp session cũ hơn 2 giờ
    claims = [c for c in claims if now - c.get('created_at', 0) < 7200]

    claim_token = uuid.uuid4().hex
    new_claim = {
        "token": claim_token,
        "hwid": hwid,
        "ip": client_ip,
        "created_at": now,
        "used": False
    }
    claims.append(new_claim)
    save_json(CLAIMS_FILE, claims)

    host = request.host_url.rstrip('/')
    direct_claim_url = f"{host}/getkey/claim?token={claim_token}&hwid={hwid}"

    # Tạo chuỗi rút gọn 3 lần: Ontops -> Layma 1 -> Layma 2 -> Direct Claim
    redirect_short_url = get_3tier_shortlink(direct_claim_url)

    return render_template('getkey.html',
                           hwid=hwid or "Chưa liên kết HWID",
                           redirect_url=redirect_short_url,
                           in_cooldown=bool(existing_active_key),
                           existing_key=existing_active_key)

@app.route('/getkey/claim')
def get_key_claim():
    token = request.args.get('token', '').strip()
    hwid = request.args.get('hwid', '').strip()
    now = time.time()

    claims = load_json(CLAIMS_FILE, [])
    claim_entry = None

    for c in claims:
        if c.get('token') == token:
            claim_entry = c
            break

    if not claim_entry:
        return render_template('403.html'), 403

    if claim_entry.get('used'):
        return "<h3>Lỗi: Phiên vượt link này đã được sử dụng. Vui lòng quay lại /getkey để tạo phiên mới!</h3>", 400

    claim_entry['used'] = True
    save_json(CLAIMS_FILE, claims)

    # Tạo Key 12 Giờ (0.5 ngày)
    key_str = generate_key_string()
    duration_days = 0.5
    expires_at = now + 43200

    bound_hwids = []
    if hwid:
        bound_hwids.append({
            "hwid": hwid,
            "device_name": "Get Key 12H Device",
            "registered_at": time.strftime("%Y-%m-%d %H:%M:%S")
        })

    new_key = {
        "key": key_str,
        "duration_days": duration_days,
        "device_limit": 1,
        "status": "active",
        "created_at": now,
        "first_activated_at": now,
        "expires_at": expires_at,
        "bound_hwids": bound_hwids,
        "note": "Get Key 12H Vượt Link (Ontops + Layma x2)"
    }

    keys = load_json(KEYS_FILE, [])
    keys.insert(0, new_key)
    save_json(KEYS_FILE, keys)

    return render_template('claim_success.html', key=key_str, hwid=hwid or "1 Thiết Bị")

# MARK: - Brand & Seller Token API

@app.route('/api/brand', methods=['GET'])
def api_get_brand():
    token_str = request.args.get('token', '').strip().upper()
    tokens = load_json(TOKENS_FILE, [])
    settings = get_settings()

    matched = None
    if token_str:
        for t in tokens:
            if t.get('token', '').upper() == token_str and t.get('is_active', True):
                matched = t
                break

    if matched:
        return jsonify({
            "success": True,
            "app_name": matched.get('app_name', settings.get('default_app_name', 'MeoMeoPath')),
            "welcome_title": matched.get('welcome_title', settings.get('default_welcome_title', 'CHÀO MỪNG ĐẾN APIMEOMEO')),
            "welcome_subtitle": matched.get('welcome_subtitle', settings.get('default_welcome_subtitle', '')),
            "telegram_url": matched.get('telegram_url', settings.get('emergency_link_url', 'https://t.me/ioscrackvn')),
            "telegram_title": matched.get('telegram_title', settings.get('emergency_link_title', 'LIÊN HỆ TELEGRAM'))
        })

    return jsonify({
        "success": False,
        "app_name": settings.get('default_app_name', 'MeoMeoPath'),
        "welcome_title": settings.get('default_welcome_title', 'CHÀO MỪNG ĐẾN APIMEOMEO'),
        "welcome_subtitle": settings.get('default_welcome_subtitle', 'Hệ thống Mod & Patch Tối Ưu Game Free Fire Chuyên Nghiệp'),
        "telegram_url": settings.get('emergency_link_url', 'https://t.me/ioscrackvn'),
        "telegram_title": settings.get('emergency_link_title', 'LIÊN HỆ TELEGRAM')
    })

@app.route('/api/brand/create', methods=['POST'])
def api_create_brand():
    data = request.get_json(silent=True) or {}
    token_str = data.get('token', '').strip().upper() or generate_seller_token()
    app_name = data.get('app_name', '').strip() or 'MeoMeoPath'
    welcome_title = data.get('welcome_title', '').strip() or f'CHÀO MỪNG ĐẾN {app_name.upper()}'
    welcome_subtitle = data.get('welcome_subtitle', '').strip() or 'Hệ thống Mod Free Fire VIP'
    telegram_url = data.get('telegram_url', '').strip() or 'https://t.me/ioscrackvn'
    telegram_title = data.get('telegram_title', '').strip() or 'LIÊN HỆ TELEGRAM SELLER'
    note = data.get('note', '').strip()

    tokens = load_json(TOKENS_FILE, [])

    for t in tokens:
        if t.get('token', '').upper() == token_str:
            return jsonify({"success": False, "error": "Mã Token Seller này đã tồn tại!"}), 400

    new_token = {
        "token": token_str,
        "app_name": app_name,
        "welcome_title": welcome_title,
        "welcome_subtitle": welcome_subtitle,
        "telegram_url": telegram_url,
        "telegram_title": telegram_title,
        "note": note,
        "is_active": True,
        "created_at": time.strftime("%Y-%m-%d %H:%M:%S")
    }

    tokens.insert(0, new_token)
    save_json(TOKENS_FILE, tokens)
    return jsonify({"success": True, "token": new_token})

@app.route('/api/brand/<token_str>', methods=['DELETE'])
def api_delete_brand(token_str):
    tokens = load_json(TOKENS_FILE, [])
    new_tokens = [t for t in tokens if t.get('token', '').upper() != token_str.upper()]
    save_json(TOKENS_FILE, new_tokens)
    return jsonify({"success": True})

@app.route('/api/brand/<token_str>/toggle', methods=['POST'])
def api_toggle_brand(token_str):
    tokens = load_json(TOKENS_FILE, [])
    for t in tokens:
        if t.get('token', '').upper() == token_str.upper():
            t['is_active'] = not t.get('is_active', True)
            break
    save_json(TOKENS_FILE, tokens)
    return jsonify({"success": True})

# MARK: - Key Verification REST API

@app.route('/api/key/verify', methods=['POST'])
def api_verify_key():
    settings = get_settings()
    if not settings.get('server_online', True) or settings.get('emergency_mode', False):
        return jsonify({
            "valid": False,
            "error_type": "server_offline",
            "message": settings.get('emergency_message', 'Phát hiện phiên bản bị can thiệp trái phép hoặc máy chủ đang bảo trì!'),
            "link_title": settings.get('emergency_link_title', 'THAM GIA TELEGRAM'),
            "link_url": settings.get('emergency_link_url', 'https://t.me/ioscrackvn')
        }), 200

    data = request.get_json(silent=True) or {}
    key_input = data.get('key', '').strip().upper()
    hwid = data.get('hwid', '').strip()
    device_name = data.get('device_name', 'iPhone')
    os_version = data.get('os_version', 'iOS')

    if not key_input:
        return jsonify({"valid": False, "message": "Vui lòng nhập API Key!"}), 400

    keys = load_json(KEYS_FILE, [])
    matched_key = None

    for k in keys:
        if k.get('key', '').upper() == key_input:
            matched_key = k
            break

    if not matched_key:
        return jsonify({
            "valid": False,
            "error_type": "key_not_found",
            "message": "Key không tồn tại hoặc đã bị xóa khỏi hệ thống!",
            "link_title": settings.get('emergency_link_title'),
            "link_url": settings.get('emergency_link_url')
        }), 200

    if matched_key.get('status') == 'banned':
        return jsonify({
            "valid": False,
            "error_type": "key_banned",
            "message": "Key của bạn đã bị khóa do vi phạm / nghi vấn crack!",
            "link_title": settings.get('emergency_link_title'),
            "link_url": settings.get('emergency_link_url')
        }), 200

    now = time.time()

    if not matched_key.get('first_activated_at'):
        matched_key['first_activated_at'] = now
        duration_days = matched_key.get('duration_days', 1)
        matched_key['expires_at'] = now + (duration_days * 86400)

    if matched_key.get('expires_at') and matched_key.get('expires_at') < now:
        matched_key['status'] = 'expired'
        save_json(KEYS_FILE, keys)
        return jsonify({
            "valid": False,
            "error_type": "key_expired",
            "message": "Key của bạn đã hết hạn sử dụng!",
            "link_title": settings.get('emergency_link_title'),
            "link_url": settings.get('emergency_link_url')
        }), 200

    bound_hwids = matched_key.get('bound_hwids', [])
    device_limit = matched_key.get('device_limit', 1)

    existing_device = next((d for d in bound_hwids if d.get('hwid') == hwid), None)
    if not existing_device:
        if len(bound_hwids) >= device_limit:
            return jsonify({
                "valid": False,
                "error_type": "hwid_mismatch",
                "message": f"Key này đã đạt giới hạn ({device_limit} thiết bị). Không thể dùng trên máy khác!",
                "link_title": settings.get('emergency_link_title'),
                "link_url": settings.get('emergency_link_url')
            }), 200

        bound_hwids.append({
            "hwid": hwid,
            "device_name": f"{device_name} ({os_version})",
            "registered_at": time.strftime("%Y-%m-%d %H:%M:%S")
        })
        matched_key['bound_hwids'] = bound_hwids

    matched_key['last_active'] = time.strftime("%Y-%m-%d %H:%M:%S")
    save_json(KEYS_FILE, keys)

    remaining_seconds = max(0, int(matched_key['expires_at'] - now))

    return jsonify({
        "valid": True,
        "key": matched_key['key'],
        "status": matched_key['status'],
        "duration_days": matched_key['duration_days'],
        "expires_at": matched_key['expires_at'],
        "remaining_seconds": remaining_seconds,
        "device_limit": matched_key['device_limit'],
        "devices_used": len(matched_key['bound_hwids'])
    })

# MARK: - Key Management Admin API

@app.route('/api/key/create', methods=['POST'])
def api_create_keys():
    data = request.get_json(silent=True) or {}
    duration_days = float(data.get('duration_days', 1))
    device_limit = int(data.get('device_limit', 1))
    quantity = min(50, max(1, int(data.get('quantity', 1))))
    note = data.get('note', '').strip()
    seller_token = data.get('seller_token', '').strip().upper()

    keys = load_json(KEYS_FILE, [])
    created_keys = []

    for _ in range(quantity):
        new_key = {
            "key": generate_key_string(),
            "duration_days": duration_days,
            "device_limit": device_limit,
            "status": "active",
            "created_at": time.time(),
            "first_activated_at": None,
            "expires_at": None,
            "bound_hwids": [],
            "note": note,
            "seller_token": seller_token
        }
        keys.insert(0, new_key)
        created_keys.append(new_key['key'])

    save_json(KEYS_FILE, keys)
    return jsonify({"success": True, "keys": created_keys})

@app.route('/api/key/<key_str>', methods=['DELETE'])
def api_delete_key(key_str):
    keys = load_json(KEYS_FILE, [])
    new_keys = [k for k in keys if k.get('key', '').upper() != key_str.upper()]
    save_json(KEYS_FILE, new_keys)
    return jsonify({"success": True})

@app.route('/api/key/<key_str>/ban', methods=['POST'])
def api_ban_key(key_str):
    keys = load_json(KEYS_FILE, [])
    for k in keys:
        if k.get('key', '').upper() == key_str.upper():
            k['status'] = 'banned' if k.get('status') != 'banned' else 'active'
            break
    save_json(KEYS_FILE, keys)
    return jsonify({"success": True})

@app.route('/api/key/<key_str>/reset_hwid', methods=['POST'])
def api_reset_hwid(key_str):
    keys = load_json(KEYS_FILE, [])
    for k in keys:
        if k.get('key', '').upper() == key_str.upper():
            k['bound_hwids'] = []
            break
    save_json(KEYS_FILE, keys)
    return jsonify({"success": True})

@app.route('/api/settings/update', methods=['POST'])
def api_update_settings():
    data = request.get_json(silent=True) or {}
    settings = get_settings()

    settings['server_online'] = bool(data.get('server_online', True))
    settings['emergency_mode'] = bool(data.get('emergency_mode', False))
    settings['emergency_link_title'] = data.get('emergency_link_title', '').strip() or "THAM GIA TELEGRAM"
    settings['emergency_link_url'] = data.get('emergency_link_url', '').strip() or "https://t.me/ioscrackvn"
    settings['emergency_message'] = data.get('emergency_message', '').strip() or "Phát hiện phiên bản bị can thiệp trái phép, vui lòng tham gia Telegram để nhận hỗ trợ!"

    save_json(SETTINGS_FILE, settings)
    return jsonify({"success": True, "settings": settings})

# MARK: - Patch Endpoints

@app.route('/api/status', methods=['GET'])
def api_status():
    settings = get_settings()
    is_emergency = not settings.get('server_online', True) or settings.get('emergency_mode', False)
    return jsonify({
        "status": "offline" if is_emergency else "online",
        "service": "MeoMeoPath Admin API",
        "version": "2.4.0",
        "server_online": settings.get('server_online', True),
        "is_emergency": is_emergency,
        "emergency_message": settings.get('emergency_message'),
        "emergency_link_title": settings.get('emergency_link_title'),
        "emergency_link_url": settings.get('emergency_link_url')
    })

@app.route('/api/patches', methods=['GET'])
def api_get_patches():
    settings = get_settings()
    if not settings.get('server_online', True) or settings.get('emergency_mode', False):
        return jsonify({"success": False, "count": 0, "patches": []})

    bundle = request.args.get('bundle')
    category = request.args.get('category')
    only_active = request.args.get('active', 'true').lower() == 'true'
    patches = load_json(PATCHES_FILE, [])

    result = []
    for p in patches:
        if bundle:
            if p.get('target_game') != bundle and p.get('target_game') != 'all':
                continue
        if category and p.get('category') != category:
            continue
        if only_active and not p.get('enabled', False):
            continue
        result.append(p)

    return jsonify({
        "success": True,
        "count": len(result),
        "patches": result
    })

@app.route('/api/upload', methods=['POST'])
def api_upload():
    if 'file' not in request.files:
        return jsonify({"success": False, "error": "Không tìm thấy file"}), 400

    file = request.files['file']
    if file.filename == '':
        return jsonify({"success": False, "error": "Chưa chọn file"}), 400

    target_game = request.form.get('target_game', 'com.dts.freefiremax')
    category = request.form.get('category', 'Aim File')
    patch_name = request.form.get('name', '').strip()
    password = request.form.get('password', '').strip()

    if file:
        raw_filename = secure_filename(file.filename) or f"patch_{int(time.time())}.3105"
        base_name = os.path.splitext(raw_filename)[0]
        unique_filename = f"{int(time.time())}_{base_name}.3105"
        filepath = os.path.join(UPLOAD_FOLDER, unique_filename)
        file.save(filepath)

        size_bytes = os.path.getsize(filepath)
        size_str = f"{size_bytes / (1024 * 1024):.2f} MB" if size_bytes > 1024 * 1024 else f"{size_bytes / 1024:.1f} KB"

        new_patch = {
            "id": str(uuid.uuid4()),
            "name": patch_name or base_name,
            "category": category,
            "filename": unique_filename,
            "original_filename": raw_filename,
            "target_game": target_game,
            "size": size_str,
            "enabled": True,
            "is_password_protected": bool(password),
            "password": password,
            "download_url": f"/api/download/{unique_filename}",
            "created_at": time.strftime("%Y-%m-%d %H:%M:%S")
        }

        patches = load_json(PATCHES_FILE, [])
        patches.insert(0, new_patch)
        save_json(PATCHES_FILE, patches)
        return jsonify({"success": True, "patch": new_patch})

    return jsonify({"success": False, "error": "Lỗi file"}), 400

@app.route('/api/patches/<patch_id>/toggle', methods=['POST'])
def api_toggle_patch(patch_id):
    patches = load_json(PATCHES_FILE, [])
    found = False
    new_state = False

    for p in patches:
        if p.get('id') == patch_id:
            p['enabled'] = not p.get('enabled', False)
            new_state = p['enabled']
            found = True
            break

    if found:
        save_json(PATCHES_FILE, patches)
        return jsonify({"success": True, "enabled": new_state})

    return jsonify({"success": False, "error": "Không tìm thấy patch"}), 404

@app.route('/api/patches/<patch_id>', methods=['DELETE'])
def api_delete_patch(patch_id):
    patches = load_json(PATCHES_FILE, [])
    new_patches = []
    deleted = False

    for p in patches:
        if p.get('id') == patch_id:
            filepath = os.path.join(UPLOAD_FOLDER, p.get('filename', ''))
            if os.path.exists(filepath):
                try: os.remove(filepath)
                except Exception: pass
            deleted = True
        else:
            new_patches.append(p)

    if deleted:
        save_json(PATCHES_FILE, new_patches)
        return jsonify({"success": True})

    return jsonify({"success": False, "error": "Không tìm thấy patch"}), 404

@app.route('/api/download/<filename>', methods=['GET'])
def api_download(filename):
    return send_from_directory(UPLOAD_FOLDER, secure_filename(filename), as_attachment=True)

if __name__ == '__main__':
    print("==================================================")
    print("🔥 MEOMEOPATH ADMIN SECURITY SERVER 🔥")
    print("👉 Secret Admin URL: http://0.0.0.0:5000/nxt2007")
    print("👉 Get Key 12H (Ontops -> Layma -> Layma): http://0.0.0.0:5000/getkey")
    print("👉 Seller Web Portal: http://0.0.0.0:5000/seller/<token>")
    print("👉 Public Root :5000 -> 403 Forbidden")
    print("==================================================")
    app.run(host='0.0.0.0', port=5000, debug=True)
