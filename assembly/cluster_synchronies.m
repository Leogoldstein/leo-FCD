function [validDirectory, clusterMatrix, NClOK, assemblystat] = cluster_synchronies(directory, Race, kmean_iter, kmeans_surrogate)
    % cluster_synchronies performs clustering on synchrony data for a single directory and saves the results.
    %
    % Inputs:
    % - directory: Directory to save the results
    % - DF: dF/F traces for the current folder
    % - MAct: Sum of max cell activities for the current folder
    % - Raster: Raster data for the current folder
    % - Race: Race data for the current folder
    % - kmean_iter: Number of iterations for k-means clustering
    % - kmeans_surrogate: Number of surrogate tests for clustering validation
    %
    % Outputs:
    % - validDirectory: Directory with significant clusters, empty if no significant clusters
    % - clusterMatrix: Matrix with cluster assignments
    % - NClOK: Number of significant clusters

    % Initialize output variables
    validDirectory = [];
    clusterMatrix = [];
    NClOK = 0;

    try
        % Perform k-means clustering optimization
        [IDX2, sCl, M, S] = kmeansopttest(Race, kmean_iter, 'var');

        % Determine the number of clusters that are statistically significant
        sClrnd = zeros(1, kmeans_surrogate);
        for i = 1:kmeans_surrogate
            sClrnd(i) = kmeansoptrnd(Race, 10, max(IDX2)); 
        end

        NCl = max(IDX2);
        NClOK = sum(sCl > prctile(sClrnd, 95)); % Use the 95th percentile threshold
        disp(['Number of significant clusters (NClOK): ' num2str(NClOK)]);

        % Process clustering results only if there are significant clusters
        if NClOK >= 1
            % Initialize variables
            R = cell(0);
            [NCell, ~] = size(Race);
            CellScore = zeros(NCell, NCl);
            CellScoreN = zeros(NCell, NCl);

            % Calculate scores for each cell in each cluster
            for i = 1:NCl
                R{i} = find(IDX2 == i);
                CellScore(:, i) = sum(Race(:, R{i}), 2);
                CellScoreN(:, i) = CellScore(:, i) / length(R{i});
            end

            % Assign each cell to the cluster where it most likely spikes
            [~, CellCl] = max(CellScoreN, [], 2);

            % Remove cells with fewer than 2 spikes in any cluster
            CellCl(max(CellScore, [], 2) < 2) = 0;

            % Create lists of cells in each significant cluster
            assemblystat = cell(0);
            for i = 1:NClOK
                assemblystat{i} = transpose(find(CellCl == i));
            end

            % Filter Race matrix to keep only significant clusters
            RaceOK = Race(:, IDX2 <= NClOK);

            % Group cells by cluster
            clusterMatrix = [];
            clusterId = zeros(NCell, 1); % Initialize cluster IDs

            for cluster = 1:NClOK
                cellsInCluster = assemblystat{cluster};
                clusterId(cellsInCluster) = cluster;
                % Combine cellsInCluster and cluster IDs in a matrix
                clusterMatrix = [clusterMatrix; cellsInCluster(:), clusterId(cellsInCluster)];
            end

            % Identify cells without clusters
            all_cell_indices = (1:NCell)'; % Indices of all cells
            clustered_cells = clusterMatrix(:, 1); % Indices of clustered cells
            unclustered_cells = setdiff(all_cell_indices, clustered_cells);

            % Add unclustered cells to the cluster matrix with cluster ID = 0
            if ~isempty(unclustered_cells)
                clusterMatrix = [clusterMatrix; unclustered_cells(:), zeros(length(unclustered_cells), 1)];
            end

            % Mark directory as valid if significant clusters exist
            validDirectory = directory;
        else
            disp(['No significant clusters found for directory: ' directory]);
        end

        % Save clustering results to a .mat file
        save(fullfile(directory, 'results_clustering.mat'), ...
             'IDX2', 'sCl', 'M', 'S', 'R', 'CellScore', 'CellScoreN', ...
             'CellCl', 'NClOK', 'RaceOK', 'clusterMatrix', 'validDirectory', 'assemblystat');
        disp(['Clustering results saved for directory: ' directory]);

    catch ME
        % Display error message if something goes wrong
        disp(['Error processing clustering for directory: ' directory]);
        disp(['Error message: ' ME.message]);
    end
end
