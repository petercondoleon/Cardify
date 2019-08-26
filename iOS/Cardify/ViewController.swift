/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Main view controller for the AR experience.
*/

import UIKit
import SceneKit
import ARKit
import MultipeerConnectivity

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    // MARK: - IBOutlets
    
    @IBOutlet weak var sessionInfoView: UIView!
    @IBOutlet weak var sessionInfoLabel: UILabel!
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var sendMapButton: UIButton!
    @IBOutlet weak var mappingStatusLabel: UILabel!
    
    // MARK: - View Life Cycle
    
    var multipeerSession: MultipeerSession!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        multipeerSession = MultipeerSession(receivedDataHandler: receivedData)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Start the view's AR session.
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration)
        
        // Set a delegate to track the number of plane anchors for providing UI feedback.
        sceneView.session.delegate = self
        
        //sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
        // Prevent the screen from being dimmed after a while as users will likely
        // have long periods of interaction without touching the screen or buttons.
        UIApplication.shared.isIdleTimerDisabled = true
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's AR session.
        sceneView.session.pause()
    }
    
    // MARK: - ARSCNViewDelegate
    
    let cardNames = ["AC", "2C", "3C", "4C", "5C", "6C", "7C", "8C", "9C", "10C", "JC", "QC", "KC", "AH", "2H", "3H", "4H", "5H", "6H", "7H", "8H", "9H", "10H", "JH", "QH", "KH"]
    
    var dragging = false
    var draggedTexture:String?
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        if let name = anchor.name, name.hasPrefix("card") {
            
            let scene = SCNScene(named: "Assets.scnassets/card.scn")!
            let cardNode = scene.rootNode.childNode(withName: "card", recursively: true)
            
            if dragging {
                cardNode?.geometry?.firstMaterial?.diffuse.contents = draggedTexture!
            } else {
                let rand = Int.random(in: 0 ..< cardNames.count)
                let cardName = "Assets.scnassets/cards/" + cardNames[rand] + ".png"
                cardNode?.geometry?.firstMaterial?.diffuse.contents = cardName
            }

            cardNode?.position = SCNVector3(anchor.transform.columns.3.x,anchor.transform.columns.3.y, anchor.transform.columns.3.z)
            
            node.addChildNode(cardNode!)
        }
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        
    }
    
    // MARK: - ARSessionDelegate
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        updateSessionInfoLabel(for: session.currentFrame!, trackingState: camera.trackingState)
    }
    
    /// - Tag: CheckMappingStatus
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        switch frame.worldMappingStatus {
        case .notAvailable, .limited:
            sendMapButton.isEnabled = false
        case .extending:
            sendMapButton.isEnabled = !multipeerSession.connectedPeers.isEmpty
        case .mapped:
            sendMapButton.isEnabled = !multipeerSession.connectedPeers.isEmpty
        }
        mappingStatusLabel.text = frame.worldMappingStatus.description
        updateSessionInfoLabel(for: frame, trackingState: frame.camera.trackingState)
    }
    
    // MARK: - ARSessionObserver
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay.
        sessionInfoLabel.text = "Session was interrupted"
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required.
        sessionInfoLabel.text = "Session interruption ended"
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        sessionInfoLabel.text = "Session failed: \(error.localizedDescription)"
        guard error is ARError else { return }
        
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        
        // Remove optional error messages.
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        
        DispatchQueue.main.async {
            // Present an alert informing about the error that has occurred.
            let alertController = UIAlertController(title: "The AR session failed.", message: errorMessage, preferredStyle: .alert)
            let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
                alertController.dismiss(animated: true, completion: nil)
                self.resetTracking(nil)
            }
            alertController.addAction(restartAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    // MARK: - Multiuser shared session
    @IBAction func handleSceneRotation(_ sender: UIRotationGestureRecognizer) {
        
//        let touchPosition = sender.location(in: sceneView)
//        if let hitTestScene = sceneView.hitTest(touchPosition, options: nil).first {
//            let node = hitTestScene.node
//            node.runAction(SCNAction.rotateBy(x: 0, y: -0.05*sender.rotation, z: 0, duration: 0))
//        }
        
    }
    
    var panNode:SCNNode?
    @IBAction func handleScenePan(_ sender: UIPanGestureRecognizer) {
        
        if sender.state == .began {
            print("Started panning")
            let pos = sender.location(in: sceneView)
            guard let hitTestScene = sceneView.hitTest(pos, options: nil).first else { return }
            panNode = hitTestScene.node
            
            dragging = true
            draggedTexture = panNode!.geometry?.firstMaterial?.diffuse.contents as! String
            
        } else if sender.state == .changed {

            if panNode != nil {
                // if the node exists delete it
                if let node = panNode, let anchor = sceneView.anchor(for: node) {
                    sceneView.session.remove(anchor: anchor)
                    node.removeFromParentNode()
                }
                panNode = nil
            } else {
                // otherwise create a new one in place
                let pos = sender.location(in: sceneView)
                guard let hitTestResult = sceneView.hitTest(pos, types: [.existingPlane]).first else { return }
                
                // Add in new position
                let anchor = ARAnchor(name: "card", transform: hitTestResult.worldTransform)
                sceneView.session.add(anchor: anchor)
                guard let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
                    else { fatalError("can't encode anchor") }
                self.multipeerSession.sendToAllPeers(data)
                
                guard let hitTestScene = sceneView.hitTest(pos, options: nil).first else { return }
                panNode = hitTestScene.node
            }
            
        } else if sender.state == .ended || sender.state == .cancelled {
            
            if panNode == nil { return }
            
            print("Ended panning")
            let pos = sender.location(in: sceneView)
            guard let hitTestResult = sceneView.hitTest(pos, types: [.existingPlane]).first else { return }
            
            // Remove the old
            if let node = panNode, let anchor = sceneView.anchor(for: node) {
                sceneView.session.remove(anchor: anchor)
                node.removeFromParentNode()
            }
            
            // Add in new position
            let anchor = ARAnchor(name: "card", transform: hitTestResult.worldTransform)
            sceneView.session.add(anchor: anchor)
            guard let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
                else { fatalError("can't encode anchor") }
            self.multipeerSession.sendToAllPeers(data)
            
            panNode = nil
            dragging = false
        }
        
    }
    
//    @IBAction func handleScenePan(_ sender: UIPanGestureRecognizer) {
//
//        if sender.state == .began {
//            print("Started panning")
//            let pos = sender.location(in: sceneView)
//            guard let hitTestScene = sceneView.hitTest(pos, options: nil).first else { return }
//            panNode = hitTestScene.node
//
//        } else if sender.state == .changed {
//
//        } else if sender.state == .ended || sender.state == .cancelled {
//
//            if panNode == nil { return }
//
//            print("Ended panning")
//            let pos = sender.location(in: sceneView)
//            guard let hitTestResult = sceneView.hitTest(pos, types: [.existingPlane]).first else { return }
//
//            // Remove the old
//            if let node = panNode, let anchor = sceneView.anchor(for: node) {
//                sceneView.session.remove(anchor: anchor)
//                node.removeFromParentNode()
//            }
//
//            // Add in new position
//            let anchor = ARAnchor(name: "card", transform: hitTestResult.worldTransform)
//            sceneView.session.add(anchor: anchor)
//            guard let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
//                else { fatalError("can't encode anchor") }
//            self.multipeerSession.sendToAllPeers(data)
//
//            panNode = nil
//        }
//
//    }
    
    /// - Tag: PlaceCharacter
    @IBAction func handleSceneTap(_ sender: UITapGestureRecognizer) {
        
        let touchPosition = sender.location(in: sceneView)
        guard let hitTestResult = sceneView.hitTest(touchPosition, types: .existingPlaneUsingExtent).first else { return }

        // Place an anchor for a virtual character. The model appears in renderer(_:didAdd:for:).
        let anchor = ARAnchor(name: "card", transform: hitTestResult.worldTransform)
        sceneView.session.add(anchor: anchor)
        
        // Send the anchor info to peers, so they can place the same content.
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
            else { fatalError("can't encode anchor") }
        self.multipeerSession.sendToAllPeers(data)
        
    }
    
    /// - Tag: GetWorldMap
    @IBAction func shareSession(_ button: UIButton) {
        sceneView.session.getCurrentWorldMap { worldMap, error in
            guard let map = worldMap
                else { print("Error: \(error!.localizedDescription)"); return }
            guard let data = try? NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
                else { fatalError("can't encode map") }
            self.multipeerSession.sendToAllPeers(data)
        }
    }
    
    var mapProvider: MCPeerID?

    /// - Tag: ReceiveData
    func receivedData(_ data: Data, from peer: MCPeerID) {
        
        do {
            if let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) {
                // Run the session with the received world map.
                let configuration = ARWorldTrackingConfiguration()
                configuration.planeDetection = .horizontal
                configuration.initialWorldMap = worldMap
                sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
                
                // Remember who provided the map for showing UI feedback.
                mapProvider = peer
            }
            else
            if let anchor = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARAnchor.self, from: data) {
                // Add anchor to the session, ARSCNView delegate adds visible content.
                sceneView.session.add(anchor: anchor)
            }
            else {
                print("unknown data recieved from \(peer)")
            }
        } catch {
            print("can't decode data recieved from \(peer)")
        }
    }
    
    // MARK: - AR session management
    
    private func updateSessionInfoLabel(for frame: ARFrame, trackingState: ARCamera.TrackingState) {
        // Update the UI to provide feedback on the state of the AR experience.
        let message: String
        
        switch trackingState {
        case .normal where frame.anchors.isEmpty && multipeerSession.connectedPeers.isEmpty:
            // No planes detected; provide instructions for this app's AR interactions.
            message = "Move around to map the environment, or wait to join a shared session."
            
        case .normal where !multipeerSession.connectedPeers.isEmpty && mapProvider == nil:
            let peerNames = multipeerSession.connectedPeers.map({ $0.displayName }).joined(separator: ", ")
            message = "Connected with \(peerNames)."
            
        case .notAvailable:
            message = "Tracking unavailable."
            
        case .limited(.excessiveMotion):
            message = "Tracking limited - Move the device more slowly."
            
        case .limited(.insufficientFeatures):
            message = "Tracking limited - Point the device at an area with visible surface detail, or improve lighting conditions."
            
        case .limited(.initializing) where mapProvider != nil,
             .limited(.relocalizing) where mapProvider != nil:
            message = "Received map from \(mapProvider!.displayName)."
            
        case .limited(.relocalizing):
            message = "Resuming session — move to where you were when the session was interrupted."
            
        case .limited(.initializing):
            message = "Initializing AR session."
            
        default:
            // No feedback needed when tracking is normal and planes are visible.
            // (Nor when in unreachable limited-tracking states.)
            message = ""
            
        }
        
        sessionInfoLabel.text = message
        sessionInfoView.isHidden = message.isEmpty
    }
    
    @IBAction func resetTracking(_ sender: UIButton?) {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    
    
}

