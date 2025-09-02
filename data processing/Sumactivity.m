function [Raster, MAct, Acttmp2, thresholds] = Sumactivity(DF, MinPeakDistance, synchronous_frames)
    % Get the dimensions of the input matrix F
    [NCell, Nz] = size(DF);

    % Initialize the binary raster matrix to zeros
    Raster = zeros(NCell, Nz);
    
    % Initialize cells to store activity information
    Acttmp2 = cell(1, NCell);
    ampli = cell(1, NCell); %#ok<NASGU>
    minithreshold = 0.1;

    % Initialize vector to store thresholds
    thresholds = zeros(1, NCell);
    
    % Detect calcium transients for each cell
    for i = 1:NCell
        % Calculate the threshold for detecting peaks
        th = max([3 * iqr(DF(i,:)), 2 * std(DF(i,:)), minithreshold]);
        thresholds(i) = th; % Save threshold for this cell
        
        % Find peaks in the data for the current cell
        [~, locs] = findpeaks(DF(i,:), 'MinPeakProminence', th, 'MinPeakDistance', MinPeakDistance);
        
        % Store the locations of the detected peaks
        Acttmp2{i} = locs;
        
        % Mark the detected peaks in the Raster matrix
        Raster(i, locs) = 1;
    end
    
    % Sum activity over n (synchronous_frames) consecutive frames
    MAct = zeros(1, Nz - synchronous_frames); % MAct = Sum active cells 
    for i = 1:(Nz - synchronous_frames)
        MAct(i) = sum(max(Raster(:, i:i+synchronous_frames), [], 2));
    end
end
