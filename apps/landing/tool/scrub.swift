import AVFoundation
import CoreVideo
// scrub <in.mp4> <out.mp4> <width> <height> <bitrateBps> <keepEveryN>
// All-intra H.264 (every frame is a keyframe) so seeking to any time is instant,
// scaled, and thinned to every Nth frame.
let a = CommandLine.arguments
let asset = AVURLAsset(url: URL(fileURLWithPath: a[1]))
let outURL = URL(fileURLWithPath: a[2]); try? FileManager.default.removeItem(at: outURL)
let W = Int(a[3])!, H = Int(a[4])!, bitrate = Int(a[5])!, every = Int(a[6])!
guard let track = asset.tracks(withMediaType: .video).first else { fatalError("no video") }
let reader = try! AVAssetReader(asset: asset)
let rOut = AVAssetReaderTrackOutput(track: track, outputSettings: [
  kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
  kCVPixelBufferWidthKey as String: W, kCVPixelBufferHeightKey as String: H])
reader.add(rOut)
let writer = try! AVAssetWriter(outputURL: outURL, fileType: .mp4)
let wIn = AVAssetWriterInput(mediaType: .video, outputSettings: [
  AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: W, AVVideoHeightKey: H,
  AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: bitrate,
    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
    AVVideoMaxKeyFrameIntervalKey: 1, AVVideoAllowFrameReorderingKey: false]])
wIn.expectsMediaDataInRealTime = false
writer.add(wIn); writer.shouldOptimizeForNetworkUse = true
reader.startReading(); writer.startWriting(); writer.startSession(atSourceTime: .zero)
let q = DispatchQueue(label: "enc"); let sem = DispatchSemaphore(value: 0)
var n = 0, kept = 0
wIn.requestMediaDataWhenReady(on: q) {
  while wIn.isReadyForMoreMediaData {
    if let s = rOut.copyNextSampleBuffer() {
      if n % every == 0 { wIn.append(s); kept += 1 }
      n += 1
    } else { wIn.markAsFinished(); writer.finishWriting { sem.signal() }; break }
  }
}
sem.wait()
print("frames read \(n), kept \(kept), status \(writer.status.rawValue)")
