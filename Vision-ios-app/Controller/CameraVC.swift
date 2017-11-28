//
//  CameraVC.swift
//  Vision
//
//  Created by ClementM on 27/11/2017.
//  Copyright © 2017 ClementM. All rights reserved.
//

import UIKit
import AVFoundation
import CoreML
import Vision

enum FlashState {
    case off
    case on
}

class CameraVC: UIViewController {
    
    // Variables
    var captureSession: AVCaptureSession!
    var cameraOutput: AVCapturePhotoOutput!
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    var photoData: Data?
    var flashControlState: FlashState = .off
    
    var speechSynthesizer = AVSpeechSynthesizer()
    
    // Outlets
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var identificationLbl: UILabel!
    @IBOutlet weak var roundedLblView: RoundedShadowView!
    @IBOutlet weak var confidenceLbl: UILabel!
    @IBOutlet weak var captureImageView: RoundedShadowImageView!
    @IBOutlet weak var flashBtn: RoundedShadowButton!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        previewLayer.frame = cameraView.bounds
        speechSynthesizer.delegate = self
        spinner.isHidden = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapCameraView))
        tap.numberOfTapsRequired = 1
        
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSession.Preset.hd1920x1080
        
        let backCamera = AVCaptureDevice.default(for: AVMediaType.video)
        
        do {
            let input = try AVCaptureDeviceInput(device: backCamera!)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            
            cameraOutput = AVCapturePhotoOutput()
            
            if captureSession.canAddOutput(cameraOutput) {
                captureSession.addOutput(cameraOutput!)
                
                previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
                previewLayer.videoGravity = AVLayerVideoGravity.resizeAspect
                previewLayer.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
                
                cameraView.layer.addSublayer(previewLayer)
                cameraView.addGestureRecognizer(tap)
                captureSession.startRunning()
            }
            
        } catch {
            debugPrint(error)
        }
    }
    
    // Functions
    @objc func didTapCameraView() {
        self.cameraView.isUserInteractionEnabled = false
        spinner.isHidden = false
        spinner.startAnimating()
        
        let settings = AVCapturePhotoSettings()
        
        // Old way
        //        let previewPixelType = settings.availablePreviewPhotoPixelFormatTypes.first!
        //        let previewFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPixelType, kCVPixelBufferWidthKey as String: 160, kCVPixelBufferHeightKey as String: 160]
        //        settings.previewPhotoFormat = previewFormat
        
        // New way
        settings.previewPhotoFormat = settings.embeddedThumbnailPhotoFormat
        
        if flashControlState == .off {
            settings.flashMode = .off
        } else {
            settings.flashMode = .on
        }
        
        cameraOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func resultsMethod(request: VNRequest, error: Error?) {
        guard let results = request.results as? [VNClassificationObservation] else { return }
        
        var highestConfidence: Float = 0
        var bestIdentifier = ""
        for classification in results {
            if classification.confidence > highestConfidence {
                highestConfidence = classification.confidence
                bestIdentifier = classification.identifier
            }
        }
        
        if highestConfidence < 0.5 {
            let unknownObjectMessage = "I'm not sure what this is. Please try again."
            self.identificationLbl.text = unknownObjectMessage
            synthesizeSpeech(fromString: unknownObjectMessage)
            self.confidenceLbl.text = ""
        } else {
            self.identificationLbl.text = bestIdentifier
            self.confidenceLbl.text = "Confidence: \(Int(highestConfidence * 100))%"
            let completeSentence = "This looks like a \(bestIdentifier) and I'm \(Int(highestConfidence * 100))% sure."
            synthesizeSpeech(fromString: completeSentence)
        }
    }
    
    func synthesizeSpeech(fromString string: String) {
        let speechUtterance = AVSpeechUtterance(string: string)
        speechSynthesizer.speak(speechUtterance)
    }
    
    // Action
    @IBAction func flashBtnPressed(_ sender: Any) {
        switch flashControlState {
        case .off:
            flashBtn.setTitle("FLASH ON", for: .normal)
            flashControlState = .on
        case .on:
            flashBtn.setTitle("FLASH OFF", for: .normal)
            flashControlState = .off
        }
    }
    
}

extension CameraVC: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            debugPrint(error)
        } else {
            photoData = photo.fileDataRepresentation()
            
            do {
                let model = try VNCoreMLModel(for: SqueezeNet().model)
                let request = VNCoreMLRequest(model: model, completionHandler: resultsMethod)
                let handler = VNImageRequestHandler(data: photoData!)
                try handler.perform([request])
            } catch {
                debugPrint(error)
            }
            
            let image = UIImage(data: photoData!)
            self.captureImageView.image = image
        }
    }
}

extension CameraVC: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        self.cameraView.isUserInteractionEnabled = true
        spinner.isHidden = true
        spinner.stopAnimating()
    }
}
