function [isort1, isort2, Sm, Raster, MAct, Acttmp2] = raster_processing(DF, ops, MinPeakDistance, sampling_rate, synchronous_frames, directory)
    % raster_processing processes data given DF and ops, and saves results for a single directory.
    %
    % Inputs:
    % - DF: Data matrix (dF/F) for the single directory
    % - ops: ops structure for the single directory
    % - MinPeakDistance: Minimum distance between peaks in frames
    % - synchronous_frames: Number of synchronous frames for activity calculation
    % - directory: Directory to save individual results
    %
    % Outputs:
    % - isort1: Sorted data from first sorting step
    % - isort2: Sorted data from second sorting step
    % - Sm: Sm matrix for the single directory
    % - Raster: Raster data for the single directory
    % - MAct: MAct vector for the single directory
    % - Acttmp2: Temporary activity data for the single directory

    try
        % Process raster plots
        [isort1, isort2, Sm] = processRasterPlots(DF, ops);
        
        % Call Sumactivity to get raster and activity data
        [DF, Raster, MAct, Acttmp2] = Sumactivity(DF, MinPeakDistance, synchronous_frames);
        
        % Convert Python Dictionary to MATLAB Dictionary or Structure
        ops = dictionary(ops);

        % Save individual results for the current directory
        save(fullfile(directory, 'results_raster.mat'), 'MinPeakDistance', 'sampling_rate', 'synchronous_frames', 'DF', 'ops', 'isort1', 'isort2', 'Sm', 'Raster', 'MAct', 'Acttmp2');
        
    catch ME
        % If there's an error, display a warning
        warning('Error processing raster plots for directory %s: %s', directory, ME.message);
    end
end