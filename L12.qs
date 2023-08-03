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

namespace QMC {

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

    // AND gate
    operation And(riskFactors: Qubit[], riskMeasures: Qubit[], depth: Int) : Unit is Adj + Ctl {
        Controlled X(riskFactors[0..1], riskMeasures[1]);
        for i in 2 .. Min([depth, Length(riskFactors) - 1]) {
            Controlled X([riskFactors[i], riskMeasures[i-1]], riskMeasures[i]);
        }
        if (depth == Length(riskFactors)) {
            Controlled X([riskMeasures[0], riskMeasures[Length(riskMeasures)-2]], riskMeasures[Length(riskMeasures)-1]);
        }
    }

    operation MeasureMax(riskFactors: Qubit[], riskMeasures: Qubit[]) : Unit is Adj + Ctl {
        Controlled X(riskFactors, riskMeasures[0]);
        if Length(riskMeasures) > 3 {
            Controlled X([riskFactors[Length(riskFactors)-1], riskMeasures[Length(riskMeasures)-3]], riskMeasures[0]);
        }
    }

    // Update the Risk Measurement qubit
    operation RiskMeasure(riskFactors: Qubit[], riskMeasures: Qubit[], measureMax: Bool) : Unit is Adj + Ctl {
        if not measureMax {
            ApplyToEachCA(X, riskFactors);
            MeasureMax(riskFactors, riskMeasures);
            ApplyToEachCA(X, riskFactors);
        } else {
            MeasureMax(riskFactors, riskMeasures);
        }
    }

    // Exact same as the example Q gate demonstrated in the paper
    operation QInterference(riskFactors: Qubit[], riskMeasures: Qubit[], rotation: Double, measureMax: Bool) : Unit is Ctl {

        // XZX, flip phase's sign only if RM = |0> - preparing for cancellation
        X(riskMeasures[0]);
        Z(riskMeasures[0]);
        X(riskMeasures[0]);

        // M†, forms a sandwich w/ the last M
        Adjoint RiskMeasure(riskFactors, riskMeasures, measureMax);

        // D†, the negative degrees of rotations
        PrepD(riskFactors, -rotation);

        // region palindrome
        ApplyToEachC(X, riskFactors);
        X(riskMeasures[0]);
        
        And(riskFactors, riskMeasures, Length(riskFactors));
        Controlled Z([riskMeasures[Length(riskMeasures)-1]], riskMeasures[0]); // Center of the Palindrome
        Adjoint And(riskFactors, riskMeasures, Length(riskFactors));

        X(riskMeasures[0]);
        ApplyToEachC(X, riskFactors);
        // endregion

        PrepD(riskFactors, rotation);

        // M sandwich ends
        RiskMeasure(riskFactors, riskMeasures, measureMax);
    }

    // Output Amplifications - the bunch of Q gates
    operation AmplifyOutput(riskFactors: Qubit[], riskMeasures: Qubit[], output: Qubit[], rotation: Double, measureMax: Bool) : Unit {
        // Use every output qubit as the control bit
        for i in 0 .. Length(output) - 1 {
            let qCount = 2 ^ i;
            
            // Apply Q gate 2 ^ qubit-index times
            for _ in 0 .. qCount - 1 {
                Controlled QInterference([output[i]], (riskFactors, riskMeasures, rotation, measureMax));
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
    operation MainOp(volatility: Double, drift: Double, totalTime: Int, steps: Int, numOutput: Int, measureMax: Bool) : Result[] {
        // Initializations
        use riskFactors = Qubit[steps];
        use riskMeasures = Qubit[steps+1];
        use output = Qubit[numOutput];

        let dT = IntAsDouble(totalTime) / IntAsDouble(steps);
        let volatilityOverTime = E() ^ (volatility * Sqrt(dT));
        mutable priceShiftN = (volatilityOverTime * (E()^(drift * dT)) - 1.0);
        mutable priceShiftD = (volatilityOverTime^2.0 - 1.0);
        if priceShiftD == 0.0 { // NOTE: account for floating point error?
            if priceShiftN == 0.0 {
                set priceShiftN = E()^(drift * dT);
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

        let res = MultiM(output);

        ResetAll(riskFactors+riskMeasures+output);

        return res;
    }
}
