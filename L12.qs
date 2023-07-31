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

    // Rotating probability distribution of input qubits
    operation PrepD(riskFactors: Qubit[], rotation: Double) : Unit is Ctl {
        for i in 0..Length(riskFactors) - 1 {
            Ry(rotation, riskFactors[i]);
        }
    }


    // Update the Risk Measurement qubit
    operation RiskMeasure(input: Qubit[], riskMeasure: Qubit[], measureMax: Bool) : Unit is Ctl {
        // Double CNOT gate

        if not measureMax {
            ApplyToEachC(X, input);
            Controlled X(input, riskMeasure[0]);
            ApplyToEachC(X, input);
        }
        else {
            Controlled X(input, riskMeasure[0]);
        }
    }

    // Exact same as the example Q gate demonstrated in the paper
    operation QInterference(riskFactors: Qubit[], riskMeasure: Qubit[], rotation: Double, measureMax: Bool) : Unit is Ctl {

        // XZX, flip phase's sign only if RM = |0> - preparing for cancellation
        X(riskMeasure[0]);
        Z(riskMeasure[0]);
        X(riskMeasure[0]);

        // M†, forms a sandwich w/ the last M
        RiskMeasure(riskFactors, riskMeasure, measureMax);

        // D†, the negative degrees of rotations
        PrepD(riskFactors, -rotation);

        // Palindrome
        ApplyToEachC(X, riskFactors);
        X(riskMeasure[0]);
        
        Controlled X(riskFactors, riskMeasure[1]);
        Controlled X(riskMeasure[0..1], riskMeasure[2]);
        Controlled Z([riskMeasure[2]], riskMeasure[0]); // Center of the Palindrome
        Controlled X(riskMeasure[0..1], riskMeasure[2]);
        Controlled X(riskFactors, riskMeasure[1]);

        X(riskMeasure[0]);
        ApplyToEachC(X, riskFactors);

        PrepD(riskFactors, rotation);

        // M sandwich ends
        RiskMeasure(riskFactors, riskMeasure, measureMax);

    }

    // Output Amplifications - the bunch of Q gates
    operation AmplifyOutput(riskFactors: Qubit[], riskMeasure: Qubit[], output: Qubit[], rotation: Double, measureMax: Bool) : Unit {
        // Use every output qubit as the control bit
        for i in 0 .. Length(output) - 1 {
            let qCount = 2 ^ i;
            
            // Apply Q gate for 2 ^ qubit-index times
            for _ in 0 .. qCount - 1 {
                Controlled QInterference([output[i]], (riskFactors, riskMeasure, rotation, measureMax));
            }
        }
    }

    // // Dagger
    // operation QFTDagger(output: BigEndian) : Unit{
    //     // SwapReverseRegister(output!);

    //     for i in 0 .. Length(output!)-1 {
    //         if i != 0 {
    //             for x in i .. 1 {
    //                 let degreesRotation = -PI() / 2.0^IntAsDouble(x);
    //                 let controlQubitIndex = i - x;

    //                 Controlled Rz([output![controlQubitIndex]], (degreesRotation, output![i]));
    //             }
    //         }

    //         H(output![i]);
    //     }

    // }


    // @EntryPoint() denotes the start of program execution.
    @EntryPoint()
    operation MainOp() : Result[] {
        // Initializations
        use riskFactors = Qubit[2];
        use riskMeasures = Qubit[3];
        use output = Qubit[3];
        let measureMax = true;

        // Variables
        let volatility = 0.0;
        let drift = 0.0;
        let totalTime = 1.0;
        let steps = 2.0;
        let timeStamp = totalTime / steps;

        let volatilityOverTime = E() ^ (volatility * Sqrt(timeStamp));
        mutable priceShiftN = (volatilityOverTime * (E()^(drift * timeStamp)) - 1.0);
        mutable priceShiftD = (volatilityOverTime^2.0 - 1.0);
        if priceShiftD == 0.0 { // NOTE: account for floating point error?
            if priceShiftN == 0.0 {
                // Verified
                set priceShiftN = E()^(drift * timeStamp);
                set priceShiftD = 2.0 * volatilityOverTime;
            } else {
                fail "Price shift is undefined";
            }
        }
        let priceShift = priceShiftN / priceShiftD;
        let degreesRotation = ArcSin(Sqrt(priceShift)) * 2.0;

        // Prepare input probability distribution
        PrepD(riskFactors, degreesRotation);

        // QFT
        QFT(BigEndian(output));
        SwapReverseRegister(output);

        // Store intermediate values w/ Risk Measurement qubits
        RiskMeasure(riskFactors, riskMeasures, measureMax);
        
        // Made-up Q gates for Amplitude Amplification
        AmplifyOutput(riskFactors, riskMeasures, output, degreesRotation, measureMax);

        // QFT†
        SwapReverseRegister(output);
        Adjoint QFT(BigEndian(output));

        return MultiM(output);
    // Change/add whatever you want!
    }


}
