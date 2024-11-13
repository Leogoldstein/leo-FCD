function plot_valid_directories(validDirectories, animal_date_list, all_sce_n_cells_thresholdsynchronous_frames)
    % process_valid_directories processes clustering results for directories and generates figures.
    %
    % Inputs:
    % - validDirectories: Cell array of directories with valid clustering results
    % - save_directory: Directory to save the generated figures
    % - synchronous_frames: Number of frames to consider for synchronous events
    % - sce_n_cells_threshold: Threshold for the sum of cell activity to highlight in the raster plot

    % Loop through each valid directory
    for k = 1:numel(validDirectories)
        try
            % Construct the path to the necessary files
            file_to_load1 = fullfile(validDirectories{k}, 'results_clustering.mat');
            file_to_load2 = fullfile(validDirectories{k}, 'results_SCEs.mat');
            file_to_load3 = fullfile(validDirectories{k}, 'results_raster.mat'); 
            
            % Check and load 'NClustersOK.mat'
            if exist(file_to_load1, 'file') == 2
                load(file_to_load1, 'NClOK');
            else
                error('File not found: %s', file_to_load1);
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
            
            if exist(file_to_load1, 'file') == 2
                load(file_to_load1, 'IDX2');
            else
                error('File not found: %s', file_to_load1);
            end
            
	        % Check and load 'clusterMatrix'
            if exist(file_to_load1, 'file') == 2
                load(file_to_load1, 'clusterMatrix');
            else
                error('File not found: %s', file_to_load1);
            end

            % Check and load 'Raster'
            if exist(file_to_load3, 'file') == 2
                load(file_to_load3, 'Raster');
            else
                error('File not found: %s', file_to_load3);
            end
            
            
            %  % Display the value of NClOK
            disp(['NClOK for directory ', validDirectories{k}, ': ', num2str(NClOK)]);
            [NCellOK, NRace] = size(RaceOK);

            % Reorganize RaceOK using indices
            [~, sortIdx] = sort(clusterMatrix(:,1));
            sortedRaceOK = RaceOK(clusterMatrix(sortIdx, 1), :);

            % Sort IDX2 vector and rearrange M matrix
            M = CovarM(Race);
            [~, x2] = sort(IDX2);
            MSort = M(x2, x2); % Rearrange the rows and columns of the covariance matrix M to reflect the clustering structure in IDX2

            % Create the figure
            fig = figure('Units', 'normalized', 'OuterPosition', [0 0 1 1]); % Full screen

            % First subplot: Covariance matrix
            subplot(2, 2, 1);
            imagesc(MSort);
            colormap jet;
            axis image;
            title('Covariance matrix between SCEs');
            xlabel('sorted SCE #');
            ylabel('sorted SCE #');

            % Second subplot: Repartition of cells
            subplot(2, 2, 2);
            colors = lines(NClOK);  % or any other colormap of your choice
            hold on;

            for i = 1:size(sortIdx,1)
                cluster = clusterMatrix(i, 2); % Cluster number from column 2 of clusterMatrix
                color = colors(cluster, :);  % Get color for the cluster
                plot(find(sortedRaceOK(i, :)), i, '.', 'Color', color);
            end

            hold off;
            axis tight;
            title('Repartition of cells participating in SCE after clustering');
            xlabel('sorted SCE #');
            ylabel('sorted Cell #');

            % Third subplot: Sum of cell activity
            subplot(2, 2, 4);
            NSCEsOK = size(RaceOK, 2); % SCEs
            ClusterCumulative = zeros(NClOK, NSCEsOK);
            legendLabels = cell(1, NClOK);

            for cluster = 1:NClOK
                cellsInCluster = clusterMatrix(:, 2) == cluster;
                ClusterCumulative(cluster, :) = sum(sortedRaceOK(cellsInCluster, :), 1);
                legendLabels{cluster} = ['Cluster ' num2str(cluster)];
            end

            legendLabels = legendLabels(~cellfun('isempty', legendLabels));

            hold on;
            colors = lines(NClOK); % Generate distinct colors for each cluster

            for cluster = 1:NClOK
                data = ClusterCumulative(cluster, :);
                windowSize = 5; % Define the window size for smoothing
                smoothedData = smoothdata(data, 'movmean', windowSize);
                plot(smoothedData, 'Color', colors(cluster, :), 'LineWidth', 2, 'DisplayName', ['Cluster ' num2str(cluster)]);
            end

            xlabel('SCE');
            ylabel('Sum of cell activity');
            title('Sum of cell activity according to cluster identity');

            lgd = legend(legendLabels, 'Location', 'northeastoutside');
            lgd.Position(2) = lgd.Position(2) + 0.05; % Move the legend up by adjusting the Y position

            grid on;
            box off;
            axis tight;
            hold off;


	    % Generate the figure name using animal_part and date_part
            animal_part = animal_date_list{k, 1};
            date_part = animal_date_list{k, 2};
            fig_name = sprintf('Raster_plot_of_Race_data_according_to_cluster_id of_%s_%s', animal_part, date_part);


            % Save the figure
            save_path = fullfile(validDirectories{k}, [fig_name, '.png']);
            saveas(gcf, save_path);
            close(gcf);

            %%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % Plot Raster according to cluster identity
            sortedRaster = Raster(clusterMatrix(sortIdx, 1), :);
            [NCellOK, Nz] = size(sortedRaster);
    
            fig = figure('Units', 'normalized', 'OuterPosition', [0 0 1 1]); % Full screen
    
            % Define colors for each cluster
            colors = lines(NClOK);
    
            % First subplot: RasterPlot
            subplot(2, 1, 1);  % 2 rows, 1 column, first subplot
            hold on;
    
            for i = 1:size(sortIdx,1)
                cluster = clusterMatrix(i, 2); % Cluster number from column 2 of clusterMatrix
                color = colors(cluster, :);  % Get color for the cluster
                plot(find(sortedRaster(i, :)), i, '.', 'Color', color);
            end
    
            hold off;
            xlabel('Time');
            ylabel('Cell');
            title('Raster Plot of Raster data according to cluster identity');
            xlim([1 size(sortedRaster, 2)]);
            ylim([1 size(sortedRaster, 1)]);
    

            % Second subplot: MActRaster
	    MActRaster = zeros(NClOK, Nz-synchronous_frames); % MAct = Sum active cells
	    subplot(2, 1, 2);  
            hold on;
    
            for cluster = 1:NClOK
                cellsInCluster = find(clusterMatrix(:, 2) == cluster);
    
                for i = 1:Nz-synchronous_frames
                    MActRaster(cluster, i) = sum(max(sortedRaster(cellsInCluster, i:i+synchronous_frames), [], 2));
                end
    
                plot(MActRaster(cluster, :), 'Color', colors(cluster, :), 'LineWidth', 2, 'DisplayName', ['Cluster ' num2str(cluster)]);
            end
    
            xlabel('Time frames');
            ylabel('Sum of cell activity');
	    sce_n_cells_threshold = all_sce_n_cells_threshold{k};
            yline(sce_n_cells_threshold, '--r', 'LineWidth', 2); % Change sce_n_cells_threshold as needed
    
            grid on;
            box off;
            axis tight;
            hold off;

            fig_name = sprintf('Raster_plot_of_RasterRace_data_according_to_cluster_id of_%s_%s', animal_part, date_part);

            % Save the figure
            save_path = fullfile(validDirectories{k}, [fig_name, '.png']);
            saveas(gcf, save_path);
            close(gcf);
    
        catch ME
            warning('Error processing directory %s: %s', validDirectories{k}, ME.message);
        end
    end
end