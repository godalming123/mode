function generate_wav_file(amplitudes, amplitudesLength, sampleRateInHz) {
    const numChannels = 1;

    // --- WAV File Header Constants ---
    const AUDIO_FORMAT_PCM = 1; // PCM (uncompressed)
    const SUBCHUNK1_SIZE_PCM = 16; // 16 bytes for PCM format header

    // --- Calculate sizes ---
    const bytesPerSample = 2;
    const blockAlign = numChannels * bytesPerSample; // Bytes per sample frame
    const byteRate = sampleRateInHz * blockAlign; // Bytes per second
    const dataSize = amplitudesLength * bytesPerSample; // Total size of raw audio data
    const fileSize = 44 + dataSize; // RIFF header (12) + FMT chunk (24) + DATA chunk header (8) + dataSize

    // --- Create ArrayBuffer and DataView ---
    const buffer = new ArrayBuffer(fileSize);
    const view = new DataView(buffer);
    function writeString(view, offset, str) {
        for (let i = 0; i < str.length; i++) {
            view.setUint8(offset + i, str.charCodeAt(i));
        }
    }

    // --- Write RIFF Chunk ---
    writeString(view, 0, 'RIFF'); // ChunkID
    view.setUint32(4, fileSize - 8, true); // ChunkSize (fileSize - 8 bytes for ChunkID and ChunkSize)
    writeString(view, 8, 'WAVE'); // Format

    // --- Write FMT Chunk ---
    writeString(view, 12, 'fmt '); // Subchunk1ID
    view.setUint32(16, SUBCHUNK1_SIZE_PCM, true); // Subchunk1Size (16 for PCM)
    view.setUint16(20, AUDIO_FORMAT_PCM, true); // AudioFormat (1 for PCM)
    view.setUint16(22, numChannels, true); // NumChannels
    view.setUint32(24, sampleRateInHz, true); // SampleRate
    view.setUint32(28, byteRate, true); // ByteRate
    view.setUint16(32, blockAlign, true); // BlockAlign
    view.setUint16(34, 16, true); // BitsPerSample

    // --- Write DATA Chunk ---
    writeString(view, 36, 'data'); // Subchunk2ID
    view.setUint32(40, dataSize, true); // Subchunk2Size

    // --- Write Audio Data ---
    let offset = 44; // Start of audio data
    const maxAmplitude = Math.pow(2, 16 - 1) - 1; // Max value for signed integer range

    for (let sample = amplitudes; sample.tail !== undefined; sample = sample.tail) {
        let clampedSample = Math.max(-1.0, Math.min(1.0, sample.head)); // Clamp to -1.0 to 1.0

        // Scale and convert to integer
        let scaledSample = Math.round(clampedSample * maxAmplitude);

        // Write sample
        view.setInt16(offset, scaledSample, true);
        offset += bytesPerSample;
    }

    let binary = ""
    let bytes = new Uint8Array(buffer)
    for (let i = 0; i < bytes.byteLength; i++) {
        binary += String.fromCharCode(bytes[i])
    }
    return "data:audio/wav;base64," + btoa(binary)
}

function sin(value) {return Math.sin(value)}
export {sin, generate_wav_file}
