# 🚀 快速启动指南

## 1️⃣ 安装依赖

```bash
cd server/node-music-server
npm install
```

## 2️⃣ 配置音乐库路径

编辑 `config/config.js`，修改音乐库路径：

```javascript
music: {
  rootPath: '/你的音乐文件夹路径', // 例如: '/Users/你的用户名/Music'
}
```

## 3️⃣ 启动服务器

```bash
npm start
```

服务器将自动：
- ✅ 创建数据库
- ✅ 扫描音乐文件
- ✅ 提取元数据和封面
- ✅ 启动 Web 服务

## 4️⃣ 访问 Web 界面

打开浏览器访问：
```
http://localhost:3000
```

## 5️⃣ 测试 API

```bash
# 获取所有曲目
curl http://localhost:3000/api/tracks

# 搜索
curl http://localhost:3000/api/search?q=test

# 获取统计信息
curl http://localhost:3000/api/stats
```

## 6️⃣ Flutter 集成

在 Flutter 应用中使用：

```dart
// 配置服务器地址
const baseUrl = 'http://localhost:3000';

// 获取曲目列表
final response = await http.get('$baseUrl/api/tracks');

// 播放音频
await audioPlayer.setUrl('$baseUrl/stream/${trackId}');
```

## 📝 常见问题

### Q: 端口被占用？
```bash
# 修改端口
PORT=3001 npm start
```

### Q: 扫描速度慢？
在 `config/config.js` 中调整并发数：
```javascript
scanner: {
  concurrency: 10  // 增加并发处理数
}
```

### Q: 封面图片不显示？
1. 确保安装了 ffmpeg
2. 或在音乐文件夹中放置 cover.jpg / folder.jpg

## 🎯 下一步

- 查看完整文档：[README.md](README.md)
- 浏览 API 文档：启动后访问 /api/health
- 集成到 Flutter 应用

---

享受你的音乐吧！🎵