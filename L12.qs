// Intro to Quantum Software Development
// Lab 12: Using Azure Quantum
// Copyright 2023 The MITRE Corporation. All Rights Reserved.
//
// In this lab, there are no unit tests. Instead, your goal is to successfully
// submit a job to the Microsoft Azure Quantum service. Follow the steps below.
//  1. Create a free (pay-as-you-go) Azure account:
//     https://azure.microsoft.com/en-us/pricing/purchase-options/pay-as-you-go/
//  2. Create an Azure Quantum workspace:
//     https://learn.microsoft.com/en-us/azure/quantum/how-to-create-workspace
//  3. Install the Azure CLI:
//     https://learn.microsoft.com/en-us/cli/azure/install-azure-cli
//  4. Open a terminal window and install the Azure CLI quantum extension:
//     `az extension add --upgrade -n quantum`
//  5. Connect to your Azure Quantum workspace:
//     https://learn.microsoft.com/en-us/azure/quantum/how-to-submit-re-jobs?pivots=ide-vscode-qsharp#connect-to-your-azure-quantum-workspace
//  6. Navigate to the L12 project directory and then submit the job to the
//     Resource Estimator target:
//     https://learn.microsoft.com/en-us/azure/quantum/how-to-submit-re-jobs?pivots=ide-vscode-qsharp#estimate-the-quantum-algorithm
//  7. Experiment with other targets:
//     https://learn.microsoft.com/en-us/azure/quantum/how-to-submit-jobs?pivots=ide-azurecli
//
// Alternatively, use the related documentation from the links above to submit
// a job through the web UI.

namespace MITRE.QSD.L12 {

    open Microsoft.Quantum.Canon;
    open Microsoft.Quantum.Intrinsic;
    open Microsoft.Quantum.Measurement;
    open Microsoft.Quantum.Convert;
    open Microsoft.Quantum.Arithmetic;
    open Microsoft.Quantum.Math;

    // @EntryPoint() denotes the start of program execution.
    @EntryPoint()
    operation MainOp() : Result[] {
        // Initializations
        use riskFactors = Qubit[2];
        use riskMeasures = Qubit[3];
        use output = Qubit[3];
        let drift = 0.0;

        // Prepare input probability distribution
        PrepD(riskFactors, drift);

        // QFT
        ApplyToEach(H, output);

        // Store intermediate values w/ Risk Measurement qubits
        RiskMeasure(riskFactors, riskMeasures);
        
        // Made-up Q gates for Amplitude Amplification
        AmplifyOutput(riskFactors, riskMeasures, output, drift);

        // QFT†
        SwapReverseRegister(output);
        Adjoint QFT(BigEndian(output));


        // Measure output estimation
        return MultiM(BigEndian(output)!);

    // Change/add whatever you want!
    }

    operation PrepD(riskFactors: Qubit[], drift: Double) : Unit is Adj + Ctl{
        for i in 0..Length(riskFactors)-1{
            Ry(E()^(drift*IntAsDouble(i)), riskFactors[i]);
        }
    }

    operation RiskMeasure(input: Qubit[], riskMeasure: Qubit[]) : Unit {
        // Double CNOT gate

        Controlled X(input, riskMeasure[0]);
    }

    // Exact same as the example Q gate demonstrated in the paper
    operation QInterference(riskFactors: Qubit[], riskMeasure: Qubit[], drift: Double) : Unit is Ctl {

        use temp = Qubit();
        X(temp);

        // XZX, flip phase's sign only if RM = |0> - preparing for cancellation
        X(riskMeasure[0]);
        Z(riskMeasure[0]);
        X(riskMeasure[0]);

        // M†, forms a sandwich w/ the last M
        Controlled X(riskFactors, riskMeasure[0]);

        // D†, the negative degrees of rotations
        // TODO: Modify this to the actual rotation value
        Controlled  Adjoint PrepD([temp], (riskFactors, drift));

        // Palindrome
        ApplyToEachC(X, riskFactors);
        X(riskMeasure[0]);

        Controlled X(riskFactors, riskMeasure[1]);
        Controlled X(riskMeasure[0..1], riskMeasure[2]);
        CNOT(riskMeasure[2], riskMeasure[0]);
        Controlled X(riskMeasure[0..1], riskMeasure[2]);
        Controlled X(riskFactors, riskMeasure[1]);

        X(riskMeasure[0]);
        ApplyToEachC(X, riskFactors);

        Controlled  PrepD([temp], (riskFactors, drift));

        // M sandwich ends
        Controlled X(riskFactors, riskMeasure[0]);

    }

    operation AmplifyOutput(riskFactors: Qubit[], riskMeasure: Qubit[], output: Qubit[], drift: Double) : Unit {
        for i in 0 .. Length(output) - 1 {
            let qCount = 2 ^ i;
            
            for _ in 0 .. qCount - 1 {
                Controlled QInterference([output[i]], (riskFactors, riskMeasure, drift));
            }
        }
    }

}
