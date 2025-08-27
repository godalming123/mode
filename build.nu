#!/usr/bin/env nu

let build_directory = $"($env.FILE_PWD)/build-stuff"
let build_output = $"($env.FILE_PWD)/build-output"
let gleam_version = "1.12.0"
let stdlib_version = "0.62.1"

def remove_prefix [prefix: string]: string -> string {
  if not ($in | str starts-with $prefix) {
    error make {msg: $"String `($in)` does not have the prefix `($prefix)`"}
  }
  return ($in | str substring ($prefix | str length)..-1)
}

def remove_suffix [suffix: string]: string -> string {
  if not ($in | str ends-with $suffix) {
    error make {msg: $"String `($in)` does not have the suffix `($suffix)`"}
  }
  return ($in | str substring 0..(($in | str length) - ($suffix | str length) - 1))
}

def main [command: string] {
  if $command != "debug" and $command != "optimized" {
    error make {msg: $'Expected command to be either "debug" or "optimized", but got ($command)'}
  }

  mkdir $build_directory

  let gleam_wasm_compiler_directory = $"($build_directory)/gleam-wasm-compiler-($gleam_version)"
  if not ($gleam_wasm_compiler_directory | path exists) {
    mkdir $gleam_wasm_compiler_directory
    curl --location $"https://github.com/gleam-lang/gleam/releases/download/v($gleam_version)/gleam-v($gleam_version)-browser.tar.gz"
    | tar xz -C $gleam_wasm_compiler_directory
  }

  let gleam_stdlib_directory = $"($build_directory)/stdlib-($stdlib_version)"
  if not ($gleam_stdlib_directory | path exists) {
    curl --location $"https://github.com/gleam-lang/stdlib/archive/refs/tags/v($stdlib_version).tar.gz" | tar xz -C $build_directory
    let working_directory = pwd
    cd $gleam_stdlib_directory
    gleam build --target javascript
    cd $working_directory
    let stdlib_object_contents = glob $"($gleam_stdlib_directory)/src/gleam/**/*.gleam"
      | each {
          |fileName|
          let key = $fileName
            | remove_prefix $"($gleam_stdlib_directory)/src/"
            | remove_suffix ".gleam"
          let value = open $fileName
            | str replace --all "\\" "\\\\"
            | str replace --all "`" "\\`"
          $'"($key)": `($value)`,'
        }
      | str join "\n"
    $"export default {\n($stdlib_object_contents)\n}" | save $"($gleam_stdlib_directory)/stdlib.js"
  }

  rm -rf $build_output
  mkdir $build_output

  # Compile and copy code
  if $command == "optimized" {
    elm make src/Main.elm --optimize --output $"($build_directory)/elm.js"
    uglifyjs $"($build_directory)/elm.js" --compress "pure_funcs=[F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9],pure_getters,keep_fargs=false,unsafe_comps,unsafe"
    | uglifyjs --mangle --output $"($build_output)/elm.js"
  } else {
    elm make src/Main.elm --output $"($build_output)/elm.js"
  }
  cp src/index.html $build_output
  cp src/gleam.gleam $build_output
  cp src/javascript.js $build_output
  cp src/worker.js $build_output

  # Copy gleam WASM compiler
  cp $"($gleam_wasm_compiler_directory)/gleam_wasm.js" $"($build_output)"
  cp $"($gleam_wasm_compiler_directory)/gleam_wasm_bg.wasm" $"($build_output)"

  # Copy gleam standard library
  cp -r $"($gleam_stdlib_directory)/build/dev/javascript/gleam_stdlib/gleam" $build_output
  cp $"($gleam_stdlib_directory)/build/dev/javascript/gleam_stdlib/gleam_stdlib.mjs" $build_output
  cp $"($gleam_stdlib_directory)/build/dev/javascript/gleam_stdlib/dict.mjs" $build_output
  cp $"($gleam_stdlib_directory)/build/dev/javascript/prelude.mjs" $"($build_output)/gleam.mjs"
  cp $"($gleam_stdlib_directory)/stdlib.js" $build_output 
}
