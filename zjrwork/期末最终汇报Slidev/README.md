# 低空物流服务优化 Slidev 汇报版

## 推荐分享方式

如果希望别人也能看到动态背景、点击交互和页面跳转，直接把整个 `期末最终汇报Slidev` 文件夹压缩发给对方。对方电脑需要先安装 Node.js，然后按下面步骤运行。

```powershell
npm install
npm run dev
```

浏览器打开：

```text
http://127.0.0.1:3030/
```

## 生成可分享文件

生成静态网页：

```powershell
npm run build
```

输出目录为 `dist`。静态网页需要用本地服务器或网站托管打开，不建议直接双击 `index.html`。

导出 PDF：

```powershell
npm run export:pdf
```

导出 PPTX：

```powershell
npm run export:pptx
```

导出的文件会放在 `dist` 目录。

## 局域网临时演示

如果对方和你在同一个 Wi-Fi，可以在你的电脑运行：

```powershell
npm run dev:lan
```

然后把终端里显示的局域网地址发给对方，例如：

```text
http://你的局域网IP:3030/
```

注意：`127.0.0.1` 只代表当前电脑，发给别人打不开。

## 前端网页链接说明

第 11 页保留了前端看板链接：

```text
http://127.0.0.1:5173/
```

这个地址同样只在运行前端看板的电脑上有效。如果别人也要打开前端看板，需要同时发送主项目，并在他们电脑上启动前端服务；如果只是看汇报，PDF/PPTX 和 Slidev 本体都可以正常浏览，只是该链接不会自动连接到你的电脑。

## 校园图片来源

- 中山大学深圳校区官网“校区风景”：https://shenzhen.sysu.edu.cn/campus/isuals
- 中山大学图书馆官网：https://library.sysu.edu.cn/

## 说明

本版本使用 `components/CityDroneBackground.vue` 和 `style.css` 生成动态城市低空背景，高楼、飞行光带和无人机均为前端动画元素，不依赖外部动态素材。
