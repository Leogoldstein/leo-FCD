function [isort1, isort2, Sm] = processRasterPlots(DF, ops)
    % Process raster plots using the rastermap algorithm
    % Input:
    % - DF: Data matrix where rows are neurons and columns are timepoints
    % - ops: Structure containing parameters for the rastermap algorithm
    % Output:
    % - isort1: Sorted neuron indices for the first dimension
    % - isort2: Sorted neuron indices for the second dimension
    % - Sm: Similarity matrix used for sorting
    
    % Define default values
    defaultOps = struct('nC', 20, 'iPC', 1:100, 'isort', [], 'useGPU', 0, 'upsamp', 100, 'sigUp', 1);
    
    % Merge default options with user provided options
    ops = mergeStructs(defaultOps, ops);

    % Check and adjust iPC to be within bounds
    [nNeurons, nTimepoints] = size(DF);
    % Perform PCA to determine the number of PCs available
    [~, S, ~] = svd(DF, 'econ');
    numPCs = size(S, 1);  % Number of available principal components
    
    if max(ops.iPC) > numPCs
        warning('ops.iPC exceeds the number of available PCs. Adjusting iPC to available range.');
        ops.iPC = 1:numPCs;  % Adjust to use all available PCs
    end

    % Run the rastermap algorithm
    [isort1, isort2, Sm] = mapTmap(DF, ops);
end

function ops = mergeStructs(defaultOps, userOps)
    % Merge default options with user provided options
    ops = defaultOps;
    fields = fieldnames(userOps);
    for i = 1:numel(fields)
        ops.(fields{i}) = userOps.(fields{i});
    end
end
