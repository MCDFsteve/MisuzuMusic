#!/bin/bash

# 切换到脚本所在目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "🎵 Misuzu Music Server - Installation Script"
echo "=============================================="
echo ""
echo "📁 Working directory: $SCRIPT_DIR"
echo ""

# 检查Node.js
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed"
    echo "   Please install Node.js 16+ from https://nodejs.org/"
    exit 1
fi

NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 16 ]; then
    echo "❌ Node.js version is too old ($(node -v))"
    echo "   Please upgrade to Node.js 16+"
    exit 1
fi

echo "✅ Node.js $(node -v) detected"
echo ""

# 检查npm
if ! command -v npm &> /dev/null; then
    echo "❌ npm is not installed"
    exit 1
fi

echo "✅ npm $(npm -v) detected"
echo ""

# 安装依赖
echo "📦 Installing dependencies..."
npm install

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Failed to install dependencies"
    exit 1
fi

echo ""
echo "✅ Dependencies installed successfully"
echo ""

# 检查ffmpeg (可选)
if command -v ffmpeg &> /dev/null; then
    echo "✅ ffmpeg detected (optional, for enhanced cover extraction)"
else
    echo "⚠️  ffmpeg not found (optional)"
    echo "   Install ffmpeg for better cover art extraction:"
    echo "   - macOS: brew install ffmpeg"
    echo "   - Ubuntu: sudo apt install ffmpeg"
fi

echo ""

# 创建.env文件
if [ ! -f .env ]; then
    echo "📝 Creating .env file..."
    if [ -f .env.example ]; then
        cp .env.example .env
        echo "✅ .env file created from .env.example"
    else
        echo "⚠️  .env.example not found, creating default .env"
        cat > .env << 'EOF'
PORT=3301
HOST=0.0.0.0
NODE_ENV=production
MUSIC_ROOT=../music_library_data
API_KEY=misuzu-music-key
ENABLE_AUTH=false
CORS_ORIGIN=*
LOG_LEVEL=info
EOF
        echo "✅ Default .env file created"
    fi
else
    echo "ℹ️  .env file already exists"
fi

echo ""

# 读取端口配置
PORT=3301  # 默认端口
if [ -f .env ]; then
    # 从 .env 读取端口
    ENV_PORT=$(grep "^PORT=" .env | cut -d'=' -f2)
    if [ ! -z "$ENV_PORT" ]; then
        PORT=$ENV_PORT
    fi
elif [ -f config/config.js ]; then
    # 从 config.js 读取端口
    CONFIG_PORT=$(grep "port:" config/config.js | grep -o '[0-9]\+' | head -1)
    if [ ! -z "$CONFIG_PORT" ]; then
        PORT=$CONFIG_PORT
    fi
fi

# 读取主机配置
HOST="0.0.0.0"
if [ -f .env ]; then
    ENV_HOST=$(grep "^HOST=" .env | cut -d'=' -f2)
    if [ ! -z "$ENV_HOST" ]; then
        HOST=$ENV_HOST
    fi
fi

echo ""
echo "🎉 Installation complete!"
echo ""
echo "Next steps:"
echo "1. Edit config/config.js or .env to set your music library path"
echo "2. Run: npm start"
echo ""
echo "📡 Server will be available at:"
echo "   - Local:   http://localhost:$PORT"
echo "   - Network: http://$HOST:$PORT"
echo "   - Public:  http://YOUR_SERVER_IP:$PORT"
echo ""
echo "💡 To change port: Edit .env or use PORT=xxxx npm start"
echo ""
echo "For more information, see README.md and QUICKSTART.md"
echo ""