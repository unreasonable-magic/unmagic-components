// Replay with cua_repl after starting: PORT=5799 bin/dev
// Shows the component browser on an isolated port in a visible Safari tab.
var demoSafari = await cua.getApp("com.apple.Safari");
await demoSafari.pressKey("super+t");
await demoSafari.typeText("http://localhost:5799/components/button?theme=light");
await demoSafari.pressKey("Return");
await demoSafari.getAXState();
await demoSafari.getScreenshot();
await demoSafari.pressKey("super+l");
await demoSafari.typeText("http://localhost:5799/components/button?theme=dark");
await demoSafari.pressKey("Return");
await demoSafari.getAXState();
await demoSafari.getScreenshot();
