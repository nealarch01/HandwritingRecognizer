import Foundation

struct NeuralNetwork: Codable {
    private(set) var layers: [[Node]] = []
    var lastIndex: Int? { 
        if layers.count == 0 { return nil }
        return layers.count - 1 
    }
    var layerCount: Int { return layers.count }

    init(topology: NetworkTopology) {
        // Create the first layer 
        let firstLayer = createLayer(size: topology.layers[0], collectors: topology.collectors)
        layers.append(firstLayer)

        for i in 1..<topology.layers.count {
            let collectorSummation = layerSummation(atIndex: i - 1)
            let column = createLayer(
                size: topology.layers[i], 
                collectors: Array(
                    repeating: collectorSummation, 
                    count: topology.layers[i]
            ))
            layers.append(column) 
        }
    }

    mutating private func createLayer(size: Int, collectors: [Double]) -> [Node] {
        var column: [Node] = []
        for i in 0..<size {
            let newNode = Node(collector: collectors[i])
            // Go to the previous layer
            if lastIndex ?? -1 >= 0 {
                for i in 0..<layers[lastIndex!].count {
                    layers[lastIndex!][i].addConnection(node: newNode)
                }
            }
            column.append(newNode)
        }
        return column
    }

    public func traverseColumn(atIndex: Int) {
        if atIndex > lastIndex! {
            print("Layer does not exist")
            return
        }
        print("Column \(atIndex):")
        for node in layers[atIndex] {
            node.display()
        }
        print("==============================================")
    }

    public func traverseLayers() {
        if layers.count == 0 {
            print("The network is empty")
            return
        }
        for index in 0..<layers.count {
            traverseColumn(atIndex: index)
        }
    }

    public func layerSummation(atIndex: Int) -> Double {
        var sum: Double = 0.0
        for node in layers[atIndex] {
            sum += node.collector
        }
        return sum
    }

    public func setInputLayer(trainingInputs: [Double]) {
        var trainingInputsFixed = trainingInputs // if the number of training data is less than the number of input layers, append 0
        if trainingInputsFixed.count < layers[0].count - 1{
            for _ in trainingInputsFixed.count..<layers[0].count {
                trainingInputsFixed.append(0.0)
            }
        }
        for i in 0..<layers[0].count {
            layers[0][i].updateCollector(newCollector: trainingInputsFixed[i])
        }
    }

    public func transfer(activation: Double) -> Double {
        return 1.0 / (1.0 + exp(-activation))
    }

    private func activate(node: Node, inputs: [Double]) -> Double {
        var activation: Double = 0.0
        for (index, connection) in node.connections.enumerated() {
            activation += connection.weight * inputs[index]
        }
        print("Activation: \(activation)")
        return activation
    }

    private func propagateForward() {
        for layerIndex in 1..<layers.count {
            for currentNodeIndex in 0..<layers[layerIndex].count {
                var weightedSum: Double = 0.0
                for previousNodeIndex in 0..<layers[layerIndex - 1].count {
                    weightedSum += layers[layerIndex - 1][previousNodeIndex].collector * layers[layerIndex - 1][previousNodeIndex].connections[currentNodeIndex].weight
                }
                let transferedValue = transfer(activation: weightedSum)
                layers[layerIndex][currentNodeIndex].updateCollector(newCollector: transferedValue)
            }
        }
    }

    public func transferDerivative(collector: Double) -> Double {
        return collector * (1.0 - collector)
    }

   private func propagateBackward(expectedOutputs: [Double]) {
        for layerIndex in (0..<layers.count).reversed() {
            var errors: [Double] = []
            if layerIndex != layers.count - 1 { // if we are not at the output layer
                for nodeIndex in 0..<layers[layerIndex].count {
                    var error: Double = 0.0
                    for nextNodeIndex in 0..<layers[layerIndex + 1].count {
                        let weight = layers[layerIndex][nodeIndex].connections[nextNodeIndex].weight
                        let delta = layers[layerIndex + 1][nextNodeIndex].delta
                        error += (weight * delta)
                    }
                    errors.append(error)
                }
            } else { // if we are at the output layer
                for nodeIndex in 0..<layers[layerIndex].count {
                    let collector = layers[layerIndex][nodeIndex].collector
                    let error = collector - expectedOutputs[nodeIndex]
                    errors.append(error)
                }
            }
            for nodeIndex in 0..<layers[layerIndex].count {
                let delta = errors[nodeIndex] * transferDerivative(collector: layers[layerIndex][nodeIndex].collector)
                layers[layerIndex][nodeIndex].updateDelta(newDelta: delta) 
            }
        }
    }

    public func updateWeights(learningRate: Double, trainingInputs: [Double]) {
        // General formula: weight = weight - learningRate * delta * collectorFromPreviousLayer
        for layerIndex in 1..<layers.count {
            let inputs: [Double] = layers[layerIndex - 1].map { $0.collector }
            for currentLayerNodeIndex in 0..<layers[layerIndex].count {
                for prevLayerNodeIndex in 0..<layers[layerIndex - 1].count {
                    let weight = layers[layerIndex - 1][prevLayerNodeIndex].connections[currentLayerNodeIndex].weight
                    let delta = layers[layerIndex][currentLayerNodeIndex].delta
                    let collector = inputs[prevLayerNodeIndex]
                    let newWeight = weight - learningRate * delta * collector
                    layers[layerIndex - 1][prevLayerNodeIndex].connections[currentLayerNodeIndex].updateWeight(newWeight: newWeight)
                }
            }
        }
    }

    public func train(trainingInputs: [[Double]], expectedOutputs: [[Double]], learningRate: Double, epochs: Int, targetError: Double) {
        for epoch in 0..<epochs {
            var sumError: Double = 0.0
            for j in 0..<trainingInputs.count {
                setInputLayer(trainingInputs: trainingInputs[j])
                propagateForward()
                let outputs = layers.last!.map { $0.collector }
                for k in 0..<outputs.count {
                    // Add sum error here
                    let error = expectedOutputs[j][k] - outputs[k]
                    sumError += pow(error, 2)
                }
                if sumError <= targetError {
                    print("epoch: \(epoch), learning rate: \(learningRate), error: \(sumError)")
                    return
                }
                propagateBackward(expectedOutputs: expectedOutputs[j])
                updateWeights(learningRate: learningRate, trainingInputs: trainingInputs[j])
            }
            print("epoch: \(epoch), learning rate: \(learningRate), error: \(sumError)")
        }
    }

    public func test(inputs: [[Double]]) -> [[Double]] {
        var outputs: [[Double]] = []
        for i in 0..<inputs.count {
            setInputLayer(trainingInputs: inputs[i])
            propagateForward()
            let output = layers.last!.map { $0.collector }
            outputs.append(output)
        }
        return outputs
    }

    public func serialize() -> String? {
        // Pretty print the JSON
        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = .prettyPrinted
        guard let data = try? jsonEncoder.encode(self) else {
            print("An error occurred while serializing the network")
            return nil
        }
        let string = String(data: data, encoding: .utf8)
        return string
    }
}
