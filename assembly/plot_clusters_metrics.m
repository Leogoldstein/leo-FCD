function plot_clusters_metrics(validDirectories, all_NClOK, all_RaceOK, all_IDX2, all_clusterMatrix, all_Raster, all_sce_n_cells_threshold, all_synchronous_frames, current_animal_group, current_dates_group)
    % process_valid_directories processes clustering results for directories and generates figures.
    %
    % Inputs:
    % - validDirectories: Cell array of directories with valid clustering results
    % - all_NClOK: Number of clusters
    % - all_RaceOK: Data corresponding to RaceOK (presumably cell data)
    % - all_IDX2: Vector containing indices of the data
    % - all_clusterMatrix: Clustering information (with clusters per data points)
    % - all_Raster: Raster data for cells
    % - all_sce_n_cells_threshold: Threshold for the sum of cell activity to highlight in the raster plot
    % - synchronous_frames: Number of frames to consider for synchronous events

    % Loop through each valid directory
    for k = 1:numel(validDirectories)
        try
            % Access data for the current directory
            RaceOK = all_RaceOK{k};
            clusterMatrix = all_clusterMatrix{k};
            Raster = all_Raster{k};
            NClOK = all_NClOK(k);
            IDX2 = all_IDX2{k};
            sce_n_cells_threshold = all_sce_n_cells_threshold{k};
            synchronous_frames = all_synchronous_frames{k};
    
            % Reorganize RaceOK using indices
            [~, sortIdx] = sort(clusterMatrix(:, 1));
            sortedRaceOK = RaceOK(clusterMatrix(sortIdx, 1), :);

            % Sort IDX2 vector and rearrange M matrix
            M = CovarM(RaceOK);  % Assuming CovarM is a function that takes RaceOK and returns a covariance matrix
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

            for i = 1:size(sortIdx, 1)
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

            fig_name = sprintf('Raster_plot_of_Race_data_according_to_cluster_id_of_%s_%s', current_animal_group, current_dates_group{k});

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

            for i = 1:size(sortIdx, 1)
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
            MActRaster = zeros(NClOK, Nz - synchronous_frames); % MAct = Sum active cells
            subplot(2, 1, 2);  
            hold on;

            for cluster = 1:NClOK
                cellsInCluster = find(clusterMatrix(:, 2) == cluster);

                for i = 1:Nz - synchronous_frames
                    MActRaster(cluster, i) = sum(max(sortedRaster(cellsInCluster, i:i + synchronous_frames), [], 2));
                end

                plot(MActRaster(cluster, :), 'Color', colors(cluster, :), 'LineWidth', 2, 'DisplayName', ['Cluster ' num2str(cluster)]);
            end

            xlabel('Time frames');
            ylabel('Sum of cell activity');
            yline(sce_n_cells_threshold, '--r', 'LineWidth', 2); % Change sce_n_cells_threshold as needed

            grid on;
            box off;
            axis tight;
            hold off;

            fig_name = sprintf('Raster_plot_of_RasterRace_data_according_to_cluster_id_of_%s_%s', current_animal_group, current_dates_group{k});

            % Save the figure
            save_path = fullfile(validDirectories{k}, [fig_name, '.png']);
            saveas(gcf, save_path);
            close(gcf);

        catch ME
            warning('Error processing directory %s: %s', validDirectories{k}, ME.message);
        end
    end
end
