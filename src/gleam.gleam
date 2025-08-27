import gleam/float
import gleam/int
import gleam/io
import gleam/list

// TODO: Add overtones

const pi = 3.14159

fn generate_sin_wave(
  frequency_in_hz: Float,
  duration_in_seconds: Float,
  sample_rate_in_hz: Int,
) -> List(Float) {
  list.range(
    0,
    float.round(duration_in_seconds *. int.to_float(sample_rate_in_hz)) - 1,
  )
  |> list.map(fn(timestamp) {
    sin(
      { int.to_float(timestamp) *. frequency_in_hz *. 2.0 *. pi }
      /. int.to_float(sample_rate_in_hz),
    )
  })
}

fn skip_some_loop(
  list: List(a),
  number_to_include: Int,
  number_to_skip: Int,
  out: List(a),
) -> List(a) {
  // TODO: Consider using `list.sized_chunk`
  case list.is_empty(list) {
    True -> out
    False -> {
      let #(included_elements, elements_after_included) =
        list.split(list, number_to_include)
      let #(_excluded_elements, rest) =
        list.split(elements_after_included, number_to_skip)
      skip_some_loop(
        rest,
        number_to_include,
        number_to_skip,
        list.append(out, included_elements),
      )
    }
  }
}

fn skip_some(
  list: List(a),
  number_to_include: Int,
  number_to_skip: Int,
) -> List(a) {
  skip_some_loop(list, number_to_include, number_to_skip, [])
}

fn extend_by_repitition_loop(
  list: List(a),
  new_length: Int,
  rest: List(a),
  out: List(a),
  index: Int,
) -> List(a) {
  case index >= new_length {
    True -> out
    False ->
      case rest {
        [first, ..new_rest] ->
          extend_by_repitition_loop(
            list,
            new_length,
            new_rest,
            list.prepend(out, first),
            index + 1,
          )
        [] ->
          case list {
            [first, ..new_rest] ->
              extend_by_repitition_loop(
                list,
                new_length,
                new_rest,
                list.prepend(out, first),
                index + 1,
              )
            [] -> []
          }
      }
  }
}

fn extend_by_repitition(list: List(a), new_length: Int) -> List(a) {
  extend_by_repitition_loop(list, new_length, [], [], 0)
}

@external(javascript, "./javascript.js", "sin")
fn sin(value: Float) -> Float

@external(javascript, "./javascript.js", "generate_wav_file")
fn generate_wav_file(
  amplitudes: List(Float),
  amplitudes_length: Int,
  sample_rate_in_hz: Int,
) -> String

pub fn main() {
  io.println("Hello sound")
}

// Gets the pitch of a note in hz
pub fn get_pitch(base_hz: Float, semitone_delta: Int) -> Float {
  // 2 ^ (1 / 12)
  let semitone_difference = 1.05946309436
  case semitone_delta == 0 {
    True -> base_hz
    False ->
      case semitone_delta > 0 {
        True -> get_pitch(base_hz *. semitone_difference, semitone_delta - 1)
        False -> get_pitch(base_hz /. semitone_difference, semitone_delta + 1)
      }
  }
}

pub fn html() -> String {
  let sample_rate = 48_000
  let base_pitch = 261.63
  let amplitudes =
    list.flatten([
      generate_sin_wave(get_pitch(base_pitch, 0), 0.5, sample_rate),
      generate_sin_wave(get_pitch(base_pitch, 2), 0.5, sample_rate),
      generate_sin_wave(get_pitch(base_pitch, 4), 0.5, sample_rate),
      generate_sin_wave(get_pitch(base_pitch, 5), 0.5, sample_rate),
      generate_sin_wave(get_pitch(base_pitch, 7), 0.5, sample_rate),
      generate_sin_wave(get_pitch(base_pitch, 9), 0.5, sample_rate),
      generate_sin_wave(get_pitch(base_pitch, 11), 0.5, sample_rate),
      generate_sin_wave(get_pitch(base_pitch, 12), 0.5, sample_rate),
    ])
  // amplitudes
  // |> list.take(1_000_000)
  // |> list.map(fn(a) { io.println(float.to_string(a)) })
  "<audio controls style=\"width: 100%;\"><source src=\""
  <> generate_wav_file(
    amplitudes,
    float.round(4.0 *. int.to_float(sample_rate)),
    sample_rate,
  )
  <> "\" type=\"audio/wav\"></source></audio>"
}
