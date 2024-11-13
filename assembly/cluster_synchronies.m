function [validDirectories, all_clusterMatrix, all_NClOK] = cluster_synchronies(directories, all_DF, all_MAct, all_Raster, all_Race, kmean_iter, kmeans_surrogate)
    % cluster_synchronies performs clustering on synchrony data and saves the results.
    %
    % Inputs:
    % - directories: Cell array of directories to save the results
    % - all_DF: Cell array of dF/F traces for each folder
    % - all_MAct: Cell array of sum of max cell activities for each folder
    % - all_Raster: Cell array of raster data for each folder
    % - all_Race: Cell array of Race data for each folder
    % - kmean_iter: Number of iterations for k-means clustering
    % - kmeans_surrogate: Number of surrogate tests for clustering validation
    % - save_directory: Directory to save the clustering results
    %
    % Outputs:
    % - validDirectories: Cell array of directories with significant clusters

    % Initialize variables to store results
    all_IDX2 = cell(length(directories), 1);
    all_sCl = cell(length(directories), 1);
    all_M = cell(length(directories), 1);
    all_S = cell(length(directories), 1);
    all_R = cell(length(directories), 1);
    all_CellScore = cell(length(directories), 1);
    all_CellScoreN = cell(length(directories), 1);
    all_CellCl = cell(length(directories), 1);
    all_assemblyraw = cell(length(directories), 1);
    all_assemblystat = cell(length(directories), 1);
    all_RaceOK = cell(length(directories), 1);
    all_clusterMatrix = cell(length(directories), 1); % For storing cluster matrices
    validDirectories = {}; % List of directories with significant clusters
    all_NClOK = cell(length(directories), 1);

    % Loop through each file path
    for k = 1:length(directories)
        try
            % Extract data for the current folder from all_ lists
            DF = all_DF{k};
            MAct = all_MAct{k};
            Raster = all_Raster{k};
            Race = all_Race{k}; % Assuming you have Race data in all_Race
            
            % Display a message confirming successful data extraction
            disp(['Successfully extracted data for folder: ' directories{k}]);
            
            % Perform clustering and analysis operations
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
                if NClOK >= 1 
                    assemblystat = cell(0);     
                    j = 0;
                    for i = 1:NClOK
                        j = j + 1;
                        assemblystat{j} = transpose(find(CellCl == i));
                    end
                    validDirectory = directories{k};
                    validDirectories{end+1} = directories{k};
                    
                    disp(['Added valid directory: ' directories{k}]);

                else
                    % Handle case with no significant clusters
                    assemblyortho = cell(0);
                    assemblystat = cell(0);
                end
                
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
                    % Combine cellsInCluster and cluster IDs in a matrix
                    clusterMatrix = [clusterMatrix; cellsInCluster(:), clusterId(cellsInCluster)];
                end

                % Identification des cellules sans cluster
                all_cell_indices = (1:NCell)'; % Indices de toutes les cellules
                clustered_cells = clusterMatrix(:, 1); % Indices des cellules déjà assignées à des clusters
                
                % Identifier les cellules qui n'ont pas été assignées à des clusters
                unclustered_cells = setdiff(all_cell_indices, clustered_cells); 
                
                % Mettre à jour clusterMatrix avec les cellules sans cluster
                if ~isempty(unclustered_cells)
                    clusterMatrix = [clusterMatrix; unclustered_cells(:), zeros(length(unclustered_cells), 1)];
                end

                % Store results in lists
                all_IDX2{k} = IDX2;
                all_sCl{k} = sCl;
                all_M{k} = M;
                all_S{k} = S;
                all_R{k} = R;
                all_CellScore{k} = CellScore;
                all_CellScoreN{k} = CellScoreN;
                all_CellCl{k} = CellCl;
                all_assemblyraw{k} = assemblyraw;
                all_assemblystat{k} = assemblystat;
                all_RaceOK{k} = RaceOK;
                all_NClOK{k} = NClOK;
                all_clusterMatrix{k} = clusterMatrix;

                % Save clustering results for the current folder
                save(fullfile(directories{k}, 'results_clustering.mat'), 'IDX2', 'sCl', 'M', 'S', 'R', 'CellScore', 'CellScoreN', 'CellCl', 'NClOK', 'assemblyraw', 'assemblystat', 'RaceOK', 'clusterMatrix', 'validDirectory');
                disp(['File saved successfully: ', fullfile(directories{k}, 'results_clustering.mat')]);
                
            catch ME
                % Display an error message if something goes wrong during clustering
                disp(['Error during clustering for folder: ' directories{k}]);
                disp(['Error message: ' ME.message]);
            end
            
        catch ME
            % Display an error message if something goes wrong during data extraction
            disp(['Error extracting data for folder: ' directories{k}]);
            disp(['Error message: ' ME.message]);
        end
    end

    % Display the list of valid directories
    disp('Directories with significant clusters:');
    disp(validDirectories);
end
