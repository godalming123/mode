// Monkey patch console.log with log batching since:
// 1. Gleam uses console.log to print stuff, and mode needs to be able to show the stuff that gleam prints
// 2. Elm cannot handle too many calls to `postMessage`, so we need to batch the calls
let logsBatch = ""
console.log = function (...args) {
  logsBatch += args.map((e) => `${e}`).join(" ") + "\n"
}
setInterval(() => {
  if (logsBatch != "") {
    postMessage(["log", logsBatch, ""])
    logsBatch = ""
  }
}, 100)

const gleam_compiler = await import("./gleam_wasm.js")
await gleam_compiler.default()
gleam_compiler.initialise_panic_hook(false)

import stdlib from "./stdlib.js"
for (const [name, code] of Object.entries(stdlib)) {
  gleam_compiler.write_module(0, name, code);
}

self.onmessage = async (message) => {
  try {
    gleam_compiler.write_module(0, "main", message.data[0])
    gleam_compiler.compile_package(0, "javascript")
    const href = import.meta.url.replace("/worker.js", "")
    let jsCode = gleam_compiler.read_compiled_javascript(0, "main")
    postMessage(["js", jsCode, ""])
    jsCode = jsCode.replaceAll(
      `from "./javascript.js"`,
      `from "data:text/javascript;base64,${btoa(message.data[1])}"`,
    ).replaceAll(
      `from "./`,
      `from "${href}/`,
    )
    import("data:text/javascript;base64," + btoa(jsCode)).then(loadedJs => {
      if (loadedJs.main) {
        loadedJs.main()
      }
      if (loadedJs.html) {
        const html = loadedJs.html()
        postMessage(["html", html, ""])
      }
    }).catch(e => {
      postMessage(["error", e.toString(), ""])
    })
  } catch (e) {
    postMessage(["error", e.toString(), ""])
  }
}

const gleamCodeRequest = fetch("./gleam.gleam")
const jsCodeRequest = fetch("./javascript.js")

const gleamCodeResponse = await gleamCodeRequest
const jsCodeResponse = await jsCodeRequest

if (!gleamCodeResponse.ok) {
  throw new Error(`Http status: ${gleamCodeResponse.status}`)
}
if (!jsCodeResponse.ok) {
  throw new Error(`Http status: ${gleamCodeResponse.status}`)
}

postMessage(["ready", await gleamCodeResponse.text(), await jsCodeResponse.text()])

export {}
