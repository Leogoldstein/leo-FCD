function [validDirectory, clusterMatrix, NClOK, assemblystat] = cluster_synchronies(directory, Race, kmean_iter, kmeans_surrogate)
    try
        % Extract data for the current folder
        disp(['Successfully extracted data for folder: ' directory]);

        try
            [NCell, ~] = size(Race);
            
            % Perform k-means clustering optimization
            [IDX2, sCl, M, S] = kmeansopttest(Race, kmean_iter, 'var');
            
            % Determine the number of clusters that are statistically significant
            sClrnd = zeros(1, kmeans_surrogate);
            for i = 1:kmeans_surrogate
                sClrnd(i) = kmeansoptrnd(Race, 10, max(IDX2)); 
            end
            
            NCl = max(IDX2);
            NClOK = sum(sCl > prctile(sClrnd, 95)); % Use the 95th percentile threshold
            sClOK = sCl(1:NClOK)';
            
            disp(['nClustersOK: ' num2str(NClOK)])
            
            if NClOK < 1
                disp('No statistically significant clusters. Exiting function.');
                validDirectory = '';
                clusterMatrix = [];
                NClOK = 0;
                assemblystat = {};
                return;
            end
            
            % Initialize cluster assignment variables
            R = cell(0);
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
            [~, x1] = sort(CellCl);
            
            % Remove cells with fewer than 2 spikes in any cluster
            CellCl(max(CellScore, [], 2) < 2) = 0;
            
            % Create lists of cells in each cluster
            assemblyraw = cell(0);
            j = 0;
            for i = 1:NCl
                j = j + 1;
                assemblyraw{j} = transpose(find(CellCl == i));
            end
            
            % Create new list of cells for statistically significant clusters
            assemblystat = cell(0);     
            j = 0;
            for i = 1:NClOK
                j = j + 1;
                assemblystat{j} = transpose(find(CellCl == i));
            end
            validDirectory = directory;
            disp(['Added valid directory: ' directory]);

            % Filter Race matrix to keep only significant clusters
            RaceOK = Race(:, IDX2 <= NClOK); 
            NRaceOK = size(RaceOK, 2);
            disp(['nSCEOK: ' num2str(NRaceOK)])
            
            % Group cells by cluster
            NCellOK = size(RaceOK, 1);
            clusterId = zeros(NCellOK, 1);
            clusterMatrix = [];
            for cluster = 1:NClOK
                cellsInCluster = assemblystat{cluster};
                clusterId(cellsInCluster) = cluster;  % Replace indices with cluster ID
                clusterMatrix = [clusterMatrix; cellsInCluster(:), clusterId(cellsInCluster)];
            end

            % Identify unclustered cells
            all_cell_indices = (1:NCell)'; % Indices of all cells
            clustered_cells = clusterMatrix(:, 1); % Indices of clustered cells
            unclustered_cells = setdiff(all_cell_indices, clustered_cells); 
            
            if ~isempty(unclustered_cells)
                clusterMatrix = [clusterMatrix; unclustered_cells(:), zeros(length(unclustered_cells), 1)];
            end

            % Save clustering results for the current folder
            if ~exist(directory, 'dir')
                error('Directory does not exist: %s', directory);
            end

            save(fullfile(directory, 'results_clustering.mat'), 'IDX2', 'sCl', 'M', 'S', 'R', 'CellScore', 'CellScoreN', 'CellCl', 'NClOK', 'assemblyraw', 'assemblystat', 'RaceOK', 'clusterMatrix', 'validDirectory');
            disp(['File saved successfully: ', fullfile(directory, 'results_clustering.mat')]);

        catch ME
            disp(['Error during clustering for folder: ' directory]);
            disp(['Error message: ' ME.message]);
            disp(ME.stack);  % Log stack trace for debugging
        end
        
    catch ME
        disp(['Error extracting data for folder: ' directory]);
        disp(['Error message: ' ME.message]);
    end
end
