function [sce_n_cells_threshold, TRace, Race, sces_distances, RasterRace] = select_synchronies(directory, synchronous_frames, WinActive, DF, MAct, MinPeakDistancesce, Raster, animal, date)
    % select_synchronies processes data from a single folder, detecting synchronies (SCEs),
    % creating raster plots, and saving the results.
    %
    % Inputs:
    % - directory: Directory to save the results
    % - DF: dF/F traces for the folder
    % - MAct: Sum of max cell activities for the folder
    % - MinPeakDistance: Minimum distance between peaks in frames
    % - Raster: Raster data for the folder
    % - synchronous_frames: Number of frames considered for synchrony detection
    % - WinActive: A window of active frames
    %
    % Outputs:
    % - sce_n_cells_threshold: Threshold for the number of cells for SCE detection
    % - Race: Matrix containing Race data for the folder
    % - RasterRace: Matrix containing RasterRace data for the folder

    try
        [NCell, Nz] = size(DF);

        % Select synchronies (SCEs)

        %%%% shuffling to find threshold for number of cells for SCE detection
        MActsh = zeros(1, Nz - synchronous_frames);   
        Rastersh = zeros(NCell, Nz);   
        NShfl = 100;
        Sumactsh = zeros(Nz - synchronous_frames, NShfl);   
        
        for n = 1:NShfl
            for c = 1:NCell
                l = randi(Nz - length(WinActive));
                Rastersh(c,:) = circshift(Raster(c,:), l, 2);
            end
            for i = 1:Nz - synchronous_frames   
                MActsh(i) = sum(max(Rastersh(:, i:i + synchronous_frames), [], 2));
            end
            Sumactsh(:, n) = MActsh;
        end

        % Calculate the 99th percentile for threshold
        percentile = 95;
        sce_n_cells_threshold = prctile(Sumactsh, percentile, "all");
        sce_n_cells_threshold = max(sce_n_cells_threshold, 10); % Apply minimum threshold of 10
        disp(['sce_n_cells_threshold: ' num2str(sce_n_cells_threshold)])

        % Select synchronies (SCEs)
        [~, TRace] = findpeaks(MAct, 'MinPeakHeight', sce_n_cells_threshold, 'MinPeakDistance', MinPeakDistancesce);
        NRace = length(TRace);
        disp(['nSCE: ' num2str(NRace)])

         % Calcul des intersections et distances
        sces_distances = zeros(NRace, 2); % Matrice pour stocker les intersections et distances
        for i = 1:NRace
            % Identifiez les frames avant le pic où MAct croise le seuil
            left_idx = find(MAct(1:TRace(i)) < sce_n_cells_threshold, 1, 'last');
            if isempty(left_idx)
                left_idx = 1; % Par sécurité si aucun croisement trouvé
            end
            
            % Identifiez les frames après le pic où MAct croise le seuil
            right_idx = find(MAct(TRace(i):end) < sce_n_cells_threshold, 1, 'first');
            if isempty(right_idx)
                right_idx = Nz - TRace(i); % Par sécurité si aucun croisement trouvé
            end
            right_idx = TRace(i) + right_idx - 1;

            % Calculez la distance entre les intersections
            distance = right_idx - left_idx;

            % Stockez les résultats
            sces_distances(i, :) = [TRace(i), distance];
        end
        % Create Race and RasterRace matrices
        Race = zeros(NCell, NRace);
        RasterRace = zeros(NCell, Nz);

        for i = 1:NRace
            start_idx = max(TRace(i) - 1, 1);
            end_idx = min(TRace(i) + 2, Nz);
            Race(:, i) = max(Raster(:, start_idx:end_idx), [], 2);
            RasterRace(Race(:, i) == 1, TRace(i)) = 1;
        end

        % Plotting and saving results
        fig = figure('Units', 'normalized', 'OuterPosition', [0 0 1 1]);

        % First subplot: RasterRace
        subplot(2, 1, 1);
        hold on;
        for i = 1:NCell
            spike_times = find(RasterRace(i, :));
            y_values = i * ones(1, length(spike_times));
            plot(spike_times, y_values, '.', 'Color', 'k');
        end
        hold off;
        xlabel('Time');
        ylabel('Cell');
        title('Raster Plot of Race Data');
        xlim([1 size(RasterRace, 2)]);

        % Second subplot: Sum of Max Cell Activity with Threshold
        subplot(2, 1, 2);
        plot(MAct, 'LineWidth', 2);
        hold on;
        yline(sce_n_cells_threshold, '--r', 'LineWidth', 2);
        xlabel('Time Frames');
        ylabel('Sum of Max Cell Activity');
        title('Sum of Max Cell Activity with Threshold');
        legend('Actual Activity', 'Threshold');
        xlim([1 length(MAct)]);
        hold off;

        % Generate the figure name using animal and date
        fig_name = sprintf('Raster_plot_of_Race_data_of_%s_%s', animal, date);

        % Save the figure
        save_path = fullfile(directory, [fig_name, '.png']);
        saveas(gcf, save_path);
        close(gcf);

        % Save the results to .mat file for the current directory
        save(fullfile(directory, 'results_SCEs.mat'), 'Race', 'TRace', 'sces_distances', 'RasterRace', 'sce_n_cells_threshold');
        
    catch ME
        warning('Error processing folder %s: %s', directory, ME.message);
    end
end