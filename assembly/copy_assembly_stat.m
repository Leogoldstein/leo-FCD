%% If you want to preprocess Jure's data (.npy files)
    initial_folder = '\\10.51.106.5\data\Data\jm\jm040'; % folders where data are (this must end by animal id)
    destinationFolder = 'D:/imaging/jm_verygood/jm040'; 
    PathSave = 'D:/after_processing/Synchrony peaks/';
    
    selectedFolders = select_all_folders(initial_folder);
    
    [statPaths, FPaths, iscellPaths, spksPaths] = find_npy_folders(selectedFolders); % find folders with files required for analysis
    
    [newFPaths, newStatPaths, newIscellPaths, newSpksPaths, workingFolders] = preprocess_npy_files(FPaths, statPaths, iscellPaths, spksPaths, destinationFolder); % copy npy files in a destination folder
    
    directories = create_directories_for_saving(workingFolders, PathSave); % create directories for saving


%% If you want to preporcess Leo data's (Fall.mat files)
    initial_folder = 'D:\imaging\FCD'; % folders where data are (this must end by animal id)
    %  no destination folder
    PathSave = 'D:/after_processing/Synchrony peaks/';
    
    % Starting folder for selection
    selectedFolders = select_folders(initial_folder);
    workingFolders = find_Fall_folders(selectedFolders);
    directories = create_directories_for_saving(workingFolders, PathSave);


%% Load settings
%adapt name

%synchronous_frames=2;


    
%% Select synchronies

% Loop through each file path
for k = 1:length(workingFolders) 
    %try

        [NCell,Nz] = size(DF);
   
        MovT=transpose(1:Nz);  % MovT = column vector containing time points
    
        Raster = zeros(NCell,Nz);
        Acttmp2 = cell(1,NCell);
        ampli = cell(1,NCell);
        minithreshold=0.1;
        
        for i=1:NCell    
            th=max ([  3*iqr(DF(i,:)),  3*std(DF(i,:)) ,minithreshold]) ;
            [amplitude,locs] = findpeaks(DF(i,:),'MinPeakProminence',th,'MinPeakDistance',MinPeakDistance);
            Acttmp2{i}=locs;%%%%%%%%findchangepts(y,MaxNumChanges=10,Statistic="rms") % location of peaks
        end
        
        % f = figure('visible', 'on');
        % hold on
        % 
        for i = 1:NCell
             Raster(i, Acttmp2{i}) = 1;
        %     plot(MovT(Acttmp2{i}), F(i, Acttmp2{i}) + i - 1, '.r')
        end
        % 
        % xlabel('Time (s)')
        % ylabel('Cell Activity')
        % title('Calcium Transients Detection')
        % hold off
        
        % figure;
        % plot(MAct)
        %%%%%%%%%%%%%%%%%%%%%%%%
        % shuffling to find threshold for number of cell for sce detection
        % MActsh = zeros(1,Nz-synchronous_frames);   
        % Rastersh=zeros(NCell,Nz);   
        % NShfl=100;
        % Sumactsh=zeros(Nz-synchronous_frames,NShfl);   
        % for n=1: NShfl
        % 
        %     for c=1 : NCell
        %         l = randi(Nz-length(WinActive));
        %         Rastersh(c,:)= circshift(Raster(c,:),l,2);
        %     end
        % 
        %     for i=1:Nz-synchronous_frames   %need to use WinRest???
        %         MActsh(i) = sum(max(Rastersh(:,i:i+synchronous_frames),[],2));
        %     end
        % 
        %     Sumactsh(:,n)=MActsh;
        % n
        % end
        % % toc
        % percentile = 99; % Calculate the 5% highest point or 99
        % sce_n_cells_threshold = prctile(Sumactsh, percentile,"all");
        % % sce_n_cells_threshold =10;
        % 
        % disp(['sce_n_cells_threshold: ' num2str(sce_n_cells_threshold)])
        sce_n_cells_threshold = 20;
        %sce_n_cells_threshold =median(Sumactsh,'all');
        %sce_n_cells_threshold =3*iqr(Sumactsh,'all');    
           
        % figure;
        % plot(MAct, 'LineWidth', 2);
        % hold on;
        % yline(sce_n_cells_threshold, '--r', 'LineWidth', 2); % Red dashed line for the threshold
        % xlabel('Time Frames');
        % ylabel('Sum of Max Cell Activity');
        % title('Sum of Max Cell Activity with Threshold');
        % legend('Actual Activity', 'Threshold');
        % hold off;
        %%%%%%%%%%%%%%%%%%%%%%%%

        % Select synchronies (RACE)         % TRace=localisation SCE 
        [pks,TRace] = findpeaks(MAct,'MinPeakHeight',sce_n_cells_threshold,'MinPeakDistance',MinPeakDistance);
        % sumpeaks=sum(peaks)
        %TRace: The indices of the time points where SCEs occur
        
        NRace = length(TRace);
        disp(['nSCE: '  num2str(NRace)])
        
        % Create RasterPlots
        Race = zeros(NCell, NRace);  % Race contains cells that participate in SCE 
        RasterRace = zeros(NCell, Nz);
        
        for i = 1:NRace
            % Define the time window around each TRace(i)
            start_idx = max(TRace(i) - 1, 1);  % Ensure index is not less than 1
            end_idx = min(TRace(i) + 2, Nz);   % Ensure index is not greater than Nz
            
            % Get the maximum activity across this window
            Race(:,i) = max(Raster(:, start_idx:end_idx), [], 2);
            
            % Add the activity back to the full RasterRace
            RasterRace(Race(:,i)==1,TRace(i)) = 1; 
        end
        %%%%%%%%%%%%%%%%%%%%%%%%
        
        % Raster Plot of Race Data

        fig = figure('Units', 'normalized', 'OuterPosition', [0 0 1 1]); % Full screen

        % First subplot: RasterRace
        subplot(2, 1, 1);  % 2 rows, 1 column, first subplot
        hold on;
        for i = 1:NCell
            % Find the indices where the cell data is 1
            spike_times = find(RasterRace(i, :)); 
            % Create a y-vector of the same length as spike_times
            y_values = i * ones(1, length(spike_times));  
            % Plot the spikes for the current cell
            plot(spike_times, y_values, '.', 'Color', 'k');
        end
        hold off;
        xlabel('Time');
        ylabel('Cell');
        title('Raster Plot of Race Data');
        % Set x-axis limits to the range of the data
        xlim([1 size(RasterRace, 2)]);

        % Second subplot: Sum of Max Cell Activity with Threshold
        subplot(2, 1, 2);  % 2 rows, 1 column, second subplot
        plot(MAct, 'LineWidth', 2);
        hold on;
        yline(sce_n_cells_threshold, '--r', 'LineWidth', 2); % Red dashed line for the threshold
        xlabel('Time Frames');
        ylabel('Sum of Max Cell Activity');
        title('Sum of Max Cell Activity with Threshold');
        legend('Actual Activity', 'Threshold');
        % Set x-axis limits to the range of the data
        xlim([1 length(MAct)]);
        hold off;

        exportgraphics(gcf, [namefull 'RacePlot.png'],'Resolution',300);

        % Close the figure
        close(fig);
        
        % Add semi-transparent green vertical lines at positions of TRace
        % hold on;
        % for i = 1:length(TRace)
        %     line([TRace(i) TRace(i)], [0 NCell+1], 'Color', [0 1 0 0.1], 'LineWidth', 2);  % Adjust LineWidth and transparency
        % end
        % hold off;
        
        % Plot MAct
        %plot(MAct, 'LineWidth', 2, 'Color', 'r')
        
        %Plot speed under
        %%%%%%%%%%%%%%%%%%%%%%%%
        
        % Save
        % Save all variables to .mat files
        save([directories{k},'results.mat'])  
        %%%%%%%%%%%%%%%%%%%%%%%%

        clearvars -except PathSave daytime sampling_rate synchronous_frames MinPeakDistance workingFolders directories newFPaths newIscellPaths newSpksPaths

end
% end



%% Clustering

% Initialize a cell array to store directories with significant clusters
validDirectories = {};

for k = 1:length(workingFolders) % ou fallPaths{k};
    try
        kmean_iter = 100;
        kmeans_surrogate = 100;

        % Construct the path to the 'Race.mat' file for the specified index
        file_to_load = fullfile(directories{k}, 'results.mat');
        
        % Check if the file exists
        if exist(file_to_load, 'file')
            % Load the 'Race' variable from the 'Race.mat' file
            data = load(file_to_load, 'Race');
            Race = data.Race;
            
            % Display a message confirming successful loading
            disp(['Successfully loaded Race.mat from: ' file_to_load]);
        else
            disp(['File does not exist: ' file_to_load]);
            continue; % Skip the rest of this iteration if file is missing
        end
        
        % Begin clustering and analysis operations
        try
            [NCell, NRace] = size(Race);
            [IDX2, sCl, M, S] = kmeansopttest(Race, kmean_iter, 'var'); % Increase to 50, 100?
            % M = CovarM(Race);
            % IDX2 = kmedoids(M, NCl);
            % The output includes cluster assignments (IDX2), median silhouette values of clusters from the best clustering (sCl), covariance matrix (M), and silhouette values but of all clustering x kmean_iter times (S)

            NCl = max(IDX2);
            disp(['nClusters: ' num2str(NCl)])

            % Remove cluster non-statistically significant:
            % Basically do some SCE permutation and some clustering with the same
            % number of clusters => random clusters
            % And if the best silhouette of one cluster is higher than real data then remove this cluster.
            % Since they are sorted, remove the worst one
            
            sClrnd = zeros(1, kmeans_surrogate);
            
            % Parallel for loop for permutation testing
            parfor i = 1:kmeans_surrogate
                sClrnd(i) = kmeansoptrnd(Race, 10, NCl); 
            end
            
            % Determine the number of clusters that are statistically significant
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
            
            % Assign each cell to the cluster where it most likely spikes in terms of percentage <=> orthogonalisation
            [~, CellCl] = max(CellScoreN, [], 2);
            
            % Sort cells by their cluster assignment
            [X1, x1] = sort(CellCl);
            
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
                validDirectories{end+1} = directories{k};
                disp(['Added valid directory: ' directories{k}]);

                % Export clusteredMatrix to Excel
                % filename = 'clusterMatrix.xlsx';
                % fullPath = fullfile(directories{k}, filename);
                % columnNames = {'CellIndex', 'ClusterID'};
                % % Convert matrix to table (useful for adding column names)
                % T = array2table(clusterMatrix, 'VariableNames', columnNames);
                % % Write the table to an Excel file
                % writetable(T, fullPath);

            else
                % Handle case with no significant clusters or just one cluster
                NCl = NClOK; % Set NCl to number of significant clusters
                
                % If no clusters are significant, set assemblyortho and assemblystat to empty
                assemblyortho = cell(0);
                assemblystat = cell(0);
            end
            
            % Filter Race matrix to keep only significant clusters
            RaceOK = Race(:, IDX2 <= NClOK); % Keep only SCEs whose cells have been associated with significant clusters
            NRaceOK = size(RaceOK, 2);
            disp(['nSCEOK: ' num2str(NRaceOK)])

            save([directories{k},'results_clustering.mat'])
            disp(['File saved successfully: ', fullfile(directories{k}, 'results_clustering.mat')]);
            clearvars -except workingFolders directories validDirectories
  
        catch ME
            % Display an error message if something goes wrong during clustering
            disp(['Error during clustering for file: ' file_to_load]);
            disp(['Error message: ' ME.message]);
        end
        
    catch ME
        % Display an error message if something goes wrong during file loading
        disp(['Error loading file: ' file_to_load]);
        disp(['Error message: ' ME.message]);
    end
end

% Display the list of valid directories
disp('Directories with significant clusters:');
disp(validDirectories);
%% Plot clustering

for k = 1:numel(validDirectories)
    try
        % Construct the path to the necessary files
        file_to_load1 = fullfile(validDirectories{k}, 'results_clustering.mat');
        file_to_load2 = fullfile(validDirectories{k}, 'results.mat');
        
        % Check and load 'assemblystat.mat'
        if exist(file_to_load1, 'file') == 2
            load(file_to_load1, 'assemblystat');
        else
            error('File not found: %s', file_to_load1);
        end
        
        % Check and load 'Clusters.mat'
        if exist(file_to_load1, 'file') == 2
            load(file_to_load1, 'IDX2');
        else
            error('File not found: %s', file_to_load2);
        end
        
        % Check and load 'NClustersOK.mat'
        if exist(file_to_load1, 'file') == 2
            load(file_to_load1, 'NClOK');
        else
            error('File not found: %s', file_to_load3);
        end
        
        % Check and load 'Race.mat'
        if exist(file_to_load2, 'file') == 2
            load(file_to_load2, 'Race');
        else
            error('File not found: %s', file_to_load2);
        end

        % Check and load 'RaceOK.mat'
        if exist(file_to_load1, 'file') == 2
            load(file_to_load1, 'RaceOK');
        else
            error('File not found: %s', file_to_load1);
        end
        
        % Check and load 'Raster.mat'
        if exist(file_to_load2, 'file') == 2
            load(file_to_load2, 'Raster');
        else
            error('File not found: %s', file_to_load2);
        end
        
        % Check and load 'Raster.mat'
        if exist(file_to_load2, 'file') == 2
            load(file_to_load2, 'synchronous_frames');
        else
            error('File not found: %s', file_to_load2);
        end
        
        % Display the value of NClOK
        disp(['NClOK for directory ', validDirectories{k}, ': ', num2str(NClOK)]);
        [NCellOK, NRace] = size(RaceOK);
 
         % Group cells by cluster
         clusterId = zeros(NCellOK, 1);
         clusterMatrix = [];
         for cluster = 1:NClOK
             cellsInCluster = assemblystat{cluster};
             clusterId(cellsInCluster) = cluster;  % Replace indices with cluster ID
             % ombine cellsInCluster and cluster IDs in a matrix
              clusterMatrix = [clusterMatrix; cellsInCluster(:), clusterId(cellsInCluster)];
         end
         % clusterMatrix = clusterMatrix(clusterMatrix(:, 2) ~= 0, :);

         % Save clusterMatrix to 'results_clustering.mat'
         save(file_to_load1, 'clusterMatrix', '-append');

         % Reorganize RaceOK using indices
         [~, sortIdx] = sort(clusterMatrix(:,1));
         sortedRaceOK = RaceOK(clusterMatrix(sortIdx, 1), :);

         Sort IDX2 vector and rearrange M matrix
         M = CovarM(Race);
         [~, x2] = sort(IDX2);
         MSort = M(x2, x2); % Rearrange the rows and columns of the covariance matrix M to reflect the clustering structure in IDX2

        Create the figure
        fig = figure('Units', 'normalized', 'OuterPosition', [0 0 1 1]); % Full screen

        First subplot
        subplot(2, 2, 1);
        imagesc(MSort);
        colormap jet;
        axis image;
        title('Covariance matrix between SCEs');
        xlabel('sorted SCE #');
        ylabel('sorted SCE #');

        Second subplot
        subplot(2, 2, 2);
        %Define a colormap with a unique color for each cluster
        colors = lines(NClOK);  % or any other colormap of your choice

        hold on;

        Loop through each cell belonging to a cluster
        for i = 1:size(sortIdx,1)
            cluster = clusterMatrix(i, 2); % Cluster number from column 2 of clusterMatrix
            Ensure cluster is valid for indexing colors
            color = colors(cluster, :);  % Get color for the cluster

            Plot the data for the current cell
            Use find to get indices where cell_data is 1
            plot(find(sortedRaceOK(i, :)), i, '.', 'Color', color);
        end

        hold off;

        axis tight;
        title('Repartition of cells participating in SCE after clustering');
        xlabel('sorted SCE #');
        ylabel('sorted Cell #');

        Third subplot
        subplot(2, 2, 4);
        Initialize the matrix to store cumulative contributions
        NSCEsOK = size(RaceOK, 2); % SCEs
        ClusterCumulative = zeros(NClOK, NSCEsOK);

        Initialize a cell array to store legend labels
        legendLabels = cell(1, NClOK);

        for cluster = 1:NClOK % Loop through each cluster
            Get the indices of cells for the current cluster
            cellsInCluster = find(clusterMatrix(:, 2) == cluster);

            The cumulative contribution for the cluster is computed by summing the rows of RaceOK corresponding to the cells in the cluster.
            ClusterCumulative(cluster, :) = sum(sortedRaceOK(cellsInCluster, :), 1);

            Update the legend label for this cluster
            legendLabels{cluster} = ['Cluster ' num2str(cluster)];
        end

        Remove empty legend labels
        legendLabels = legendLabels(~cellfun('isempty', legendLabels));

        hold on;
        colors = lines(NClOK); % Generate distinct colors for each cluster

        for cluster = 1:NClOK
            Extract the data for the current cluster
            data = ClusterCumulative(cluster, :);

            Smooth the data using a moving average or any other smoothing method
            windowSize = 5; % Define the window size for smoothing
            smoothedData = smoothdata(data, 'movmean', windowSize);

            Plot the smoothed data
            plot(smoothedData, 'Color', colors(cluster, :), 'LineWidth', 2, 'DisplayName', ['Cluster ' num2str(cluster)]);
        end

        xlabel('SCE');
        ylabel('Sum of cell activity');
        title('Sum of cell activity according to cluster identity');

        Add legend and adjust its position
        lgd = legend(legendLabels, 'Location', 'northeastoutside');
        lgd.Position(2) = lgd.Position(2) + 0.05; % Move the legend up by adjusting the Y position

        grid on;
        box off;
        axis tight;
        hold off;

        Export the figure to a file
        exportgraphics(fig, fullfile(validDirectories{k}, 'ClusterAnalysis.png'), 'Resolution', 300);

        Close the figure if it was created
        if isvalid(fig)
            close(fig);
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%
        
        Plot Raster according to cluster identity
        sortedRaster = Raster(clusterMatrix(sortIdx, 1), :);
        [NCellOK, Nz] = size(sortedRaster);

        fig = figure('Units', 'normalized', 'OuterPosition', [0 0 1 1]); % Full screen

        Define colors for each cluster
        colors = lines(NClOK);

        First subplot: RasterRace
        subplot(2, 1, 1);  % 2 rows, 1 column, first subplot
        hold on;

        for i = 1:size(sortIdx,1)
            cluster = clusterMatrix(i, 2); % Cluster number from column 2 of clusterMatrix
            Ensure cluster is valid for indexing colors
            color = colors(cluster, :);  % Get color for the cluster

            Plot the data for the current cell using the corresponding color
            plot(find(sortedRaster(i, :)), i, '.', 'Color', color);
        end

        hold off;
        xlabel('Time');
        ylabel('Cell');
        title('Raster Plot of Raster data according to cluster identity');
        Set x/y-axis limits to the range of the data
        xlim([1 size(sortedRaster, 2)]);
        ylim([1 size(sortedRaster, 1)]);

        Second subplot:
        subplot(2, 1, 2);
        Initialize the matrix to store cumulative contributions
        MActRaster = zeros(NClOK,Nz-synchronous_frames);          %MAct= Sum active cells 

        hold on;

        for cluster = 1:NClOK % Loop through each cluster
            Get the indices of cells for the current cluster

            cellsInCluster = find(clusterMatrix(:, 2) == cluster);

            for i=1:Nz-synchronous_frames
                MActRaster(cluster, i) = sum(max(sortedRaster(cellsInCluster,i:i+synchronous_frames),[],2));
            end

            plot(MActRaster(cluster, :), 'Color', colors(cluster, :), 'LineWidth', 2, 'DisplayName', ['Cluster ' num2str(cluster)]);
        end

        xlabel('Time frames');
        ylabel('Sum of cell activity');
        yline(sce_n_cells_threshold, '--r', 'LineWidth', 2); % change sce_n_cells_threshold as file paths

        grid on;
        box off;
        axis tight;
        hold off;

        exportgraphics(fig, fullfile(validDirectories{k}, 'RasterPlotClusters.png'), 'Resolution', 300);

        Close the figure if it was created
        if isvalid(fig)
            close(fig);
        end

        clearvars -except validDirectories

    catch ME
        warning('Error processing directory %s: %s', validDirectories{k}, ME.message);
    end
end