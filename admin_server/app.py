import os
import json
import uuid
import time
from flask import Flask, render_template, request, jsonify, send_from_directory
from werkzeug.utils import secure_filename

app = Flask(__name__)
app.config['SECRET_KEY'] = 'meomeopath-admin-secret-2026'
UPLOAD_FOLDER = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'uploads')
DATA_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'patches.json')

os.makedirs(UPLOAD_FOLDER, exist_ok=True)

def load_patches():
    if os.path.exists(DATA_FILE):
        try:
            with open(DATA_FILE, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception:
            return []
    return []

def save_patches(patches):
    with open(DATA_FILE, 'w', encoding='utf-8') as f:
        json.dump(patches, f, indent=2, ensure_ascii=False)

@app.route('/')
def index():
    patches = load_patches()
    return render_template('index.html', patches=patches)

# MARK: - REST API Endpoints for iOS MeoMeoPath App

@app.route('/api/status', methods=['GET'])
def api_status():
    return jsonify({
        "status": "online",
        "service": "MeoMeoPath Admin API",
        "version": "1.2.0",
        "timestamp": int(time.time()),
        "supported_games": ["com.dts.freefireth", "com.dts.freefiremax"]
    })

@app.route('/api/patches', methods=['GET'])
def api_get_patches():
    bundle = request.args.get('bundle')
    category = request.args.get('category')
    only_active = request.args.get('active', 'true').lower() == 'true'
    patches = load_patches()

    result = []
    for p in patches:
        if bundle and p.get('target_game') != bundle and p.get('target_game') != 'all':
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
        return jsonify({"success": False, "error": "Không tìm thấy file tải lên"}), 400

    file = request.files['file']
    if file.filename == '':
        return jsonify({"success": False, "error": "Chưa chọn file"}), 400

    target_game = request.form.get('target_game', 'com.dts.freefiremax')
    category = request.form.get('category', 'Aim File')
    patch_name = request.form.get('name', '').strip()
    password = request.form.get('password', '').strip()
    description = request.form.get('description', '').strip()

    if file:
        raw_filename = secure_filename(file.filename)
        if not raw_filename:
            raw_filename = f"patch_{int(time.time())}.3105"
        
        # Giữ nguyên hoặc lưu đúng định dạng .3105
        base_name = os.path.splitext(raw_filename)[0]
        unique_filename = f"{int(time.time())}_{base_name}.3105"
        filepath = os.path.join(UPLOAD_FOLDER, unique_filename)
        file.save(filepath)

        size_bytes = os.path.getsize(filepath)
        size_str = f"{size_bytes / (1024 * 1024):.2f} MB" if size_bytes > 1024 * 1024 else f"{size_bytes / 1024:.1f} KB"

        patch_id = str(uuid.uuid4())
        new_patch = {
            "id": patch_id,
            "name": patch_name or base_name,
            "category": category,
            "filename": unique_filename,
            "original_filename": raw_filename,
            "target_game": target_game,
            "size": size_str,
            "enabled": True,
            "is_password_protected": bool(password),
            "password": password,
            "description": description or f"Gói patch .3105 cho {target_game}",
            "download_url": f"/api/download/{unique_filename}",
            "created_at": time.strftime("%Y-%m-%d %H:%M:%S")
        }

        patches = load_patches()
        patches.insert(0, new_patch)
        save_patches(patches)

        return jsonify({"success": True, "patch": new_patch})

    return jsonify({"success": False, "error": "Lỗi xử lý file tải lên"}), 400

@app.route('/api/patches/<patch_id>/toggle', methods=['POST'])
def api_toggle_patch(patch_id):
    patches = load_patches()
    found = False
    new_state = False

    for p in patches:
        if p.get('id') == patch_id:
            p['enabled'] = not p.get('enabled', False)
            new_state = p['enabled']
            found = True
            break

    if found:
        save_patches(patches)
        return jsonify({"success": True, "enabled": new_state})

    return jsonify({"success": False, "error": "Không tìm thấy patch"}), 404

@app.route('/api/patches/<patch_id>', methods=['DELETE'])
def api_delete_patch(patch_id):
    patches = load_patches()
    new_patches = []
    deleted = False

    for p in patches:
        if p.get('id') == patch_id:
            filepath = os.path.join(UPLOAD_FOLDER, p.get('filename', ''))
            if os.path.exists(filepath):
                try:
                    os.remove(filepath)
                except Exception:
                    pass
            deleted = True
        else:
            new_patches.append(p)

    if deleted:
        save_patches(new_patches)
        return jsonify({"success": True})

    return jsonify({"success": False, "error": "Không tìm thấy patch"}), 404

@app.route('/api/download/<filename>', methods=['GET'])
def api_download(filename):
    return send_from_directory(UPLOAD_FOLDER, secure_filename(filename), as_attachment=True)

if __name__ == '__main__':
    print("==================================================")
    print("🔥 MEOMEOPATH ADMIN WEB SERVER (3105 HUB) 🔥")
    print("👉 Web Admin: http://0.0.0.0:5000")
    print("👉 API Patch Hub: http://0.0.0.0:5000/api/patches")
    print("==================================================")
    app.run(host='0.0.0.0', port=5000, debug=True)
