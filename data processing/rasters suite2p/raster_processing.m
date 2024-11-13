function [all_isort1, all_isort2, all_Sm, all_Raster, all_MAct, all_Acttmp2] = data_processing(all_DF, all_ops, MinPeakDistance, synchronous_frames, directories)
    % data_processing processes data given DF and ops.
    %
    % Inputs:
    % - all_DF: Cell array containing DF matrices
    % - all_ops: Cell array containing ops structures
    % - MinPeakDistance: Minimum distance between peaks in frames
    % - synchronous_frames: Number of synchronous frames for activity calculation
    % - directories: Cell array of directories to save individual results
    % - save_directory: Directory to save the combined results
    %
    % Outputs:
    % - all_isort1: Cell array of sorted data (first sorting)
    % - all_isort2: Cell array of sorted data (second sorting)
    % - all_Sm: Cell array of Sm matrices
    % - all_Raster: Cell array of Raster matrices
    % - all_MAct: Cell array of MAct vectors

    % Initialize output variables
    numFolders = length(all_DF);
    all_isort1 = cell(numFolders, 1);
    all_isort2 = cell(numFolders, 1);
    all_Sm = cell(numFolders, 1);
    all_Raster = cell(numFolders, 1);
    all_MAct = cell(numFolders, 1);
    all_Acttmp2 = cell(numFolders, 1);

    % Process each dataset
    for k = 1:numFolders
        DF = all_DF{k};
        ops = all_ops{k};

        % Try processing the raster plots, handle errors if they occur
        try
            [isort1, isort2, Sm] = processRasterPlots(DF, ops);
        catch ME
            % If there's an error, display a warning and skip to the next dataset
            warning(['Error processing raster plots for workingfolder ' num2str(k) ': ' ME.message]);
            continue;  % Skip to the next iteration
        end

        % Store results if no error occurred
        all_isort1{k} = isort1;
        all_isort2{k} = isort2;
        all_Sm{k} = Sm;

        % Call your Sumactivity function
        [Raster, MAct, Acttmp2] = Sumactivity(DF, MinPeakDistance, synchronous_frames);

        % Store results
        all_Raster{k} = Raster;
        all_MAct{k} = MAct;
        all_Acttmp2{k} = Acttmp2;
	    all_ops{k} = ops;
    
        % Save individual results for the current folder
        save(fullfile (directories{k}, 'results_raster.mat'), 'MinPeakDistance', 'synchronous_frames', 'DF', 'isort1', 'isort2', 'Sm', 'Raster', 'MAct', 'ops', 'Acttmp2');
    end
end