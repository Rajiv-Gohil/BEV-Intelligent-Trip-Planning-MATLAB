function allPassed = runAllTests()
% RUNALLTESTS Executes the complete automated engineering verification test suite
%
% Runs:
%   1. testVehicleModel
%   2. testBattery
%   3. testDrivingCycle
%   4. testRouteProcessing
%   5. testEnergyCalculation
%   6. testBaselineComparison

    clc;
    fprintf('===================================================================\n');
    fprintf('   BEV ROUTE OPTIMIZATION PLATFORM — AUTOMATED TEST SUITE          \n');
    fprintf('===================================================================\n\n');

    tests = {@testVehicleModel, ...
             @testBattery, ...
             @testDrivingCycle, ...
             @testRouteProcessing, ...
             @testEnergyCalculation, ...
             @testBaselineComparison};

    testNames = {'Vehicle Dynamics & Resistance Forces', ...
                 'Battery OCV-Rint & Protection Limits', ...
                 'Driving Cycle Generation (Eco/Norm/Perf)', ...
                 'Route Processing & Elevation Smoothing', ...
                 'Energy Accounting & Conservation', ...
                 'Baseline vs Upgraded Model Benchmark'};

    n = numel(tests);
    status = strings(n, 1);
    timings = zeros(n, 1);

    for i = 1:n
        fprintf('[%d/%d] Running %s...\n', i, n, testNames{i});
        tic;
        try
            tests{i}();
            timings(i) = toc;
            status(i) = 'PASS';
            fprintf('   -> PASSED (%.3f s)\n\n', timings(i));
        catch ME
            timings(i) = toc;
            status(i) = 'FAIL';
            fprintf('   -> FAILED (%.3f s): %s\n\n', timings(i), ME.message);
        end
    end

    allPassed = all(status == 'PASS');

    % Print Summary Matrix
    fprintf('===================================================================\n');
    fprintf('                       TEST SUMMARY REPORT                         \n');
    fprintf('===================================================================\n');
    summaryTable = table(testNames', status, timings, ...
        'VariableNames', {'Test_Suite', 'Result', 'Execution_Time_s'});
    disp(summaryTable);

    if allPassed
        fprintf('>>> ALL 6 VERIFICATION TEST SUITES PASSED SUCCESSFULLY! <<<\n');
    else
        fprintf('>>> WARNING: ONE OR MORE TESTS FAILED. PLEASE REVIEW LOGS. <<<\n');
    end
    fprintf('===================================================================\n');
end
