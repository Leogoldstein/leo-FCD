function [mean_frequency_per_minute_all, std_frequency_per_minute_all] = basic_metrics(all_DF, all_Raster, all_MAct, date_group_paths, all_sampling_rate)

    % Variables pour stocker les résultats
    mean_frequency_per_minute_all = zeros(length(date_group_paths), 1);  % Moyenne de la fréquence par minute pour chaque groupe
    std_frequency_per_minute_all = zeros(length(date_group_paths), 1);   % Ecart-type de la fréquence par minute pour chaque groupe
    
    for m = 1:length(date_group_paths)
        try
            % Extract data from the input cell arrays
            DF = all_DF{m};
            Raster = all_Raster{m};
            MAct = all_MAct{m};
            sampling_rate = all_sampling_rate{m};  % Sampling rate in Hz
    
            % Filter out neurons with NaN values from DF
            valid_neurons = all(~isnan(DF), 2);  % Check for NaN values in each row (neuron)
            DF = DF(valid_neurons, :);           % Keep only rows without NaN values
    
            % Get dimensions of DF
            [NCell, Nframes] = size(Raster);
    
            % Calculate the activity frequency per minute for each neuron
            mean_activity = mean(Raster, 2);  % Mean activity for each neuron
            frequency_per_minute = mean_activity * sampling_rate * 60;  % Activity frequency per minute
    
            % Store the mean and standard deviation of frequency per minute for each group
            mean_frequency_per_minute_all(m) = mean(frequency_per_minute);   % Mean frequency per minute for group m
            std_frequency_per_minute_all(m) = std(frequency_per_minute);     % Standard deviation of frequency per minute for group m
    
            % Create a new figure for the current unique animal group
            figure;
            screen_size = get(0, 'ScreenSize');  % Get screen size
            set(gcf, 'Position', screen_size);   % Set the figure size to the screen's resolution
    
            % First subplot: Histogram of frequency per minute
            subplot(3, 1, 1);  % 3 rows, 1 column, 1st subplot
    
            % Plot the histogram of frequency per minute
            histogram(frequency_per_minute, 'FaceColor', [0.2, 0.6, 0.8], 'EdgeColor', 'k');
            
            % Customize the histogram
            title('Distribution des fréquences des activités (par minute)', 'FontSize', 14);
            ylabel('Nombre de neurones', 'FontSize', 12);
            xlabel('Fréquence des activités (par minute)', 'FontSize', 12);
            grid on;
    
            % Second subplot: Raw data with X-axis in minutes
            subplot(3, 1, 2);  % 3 rows, 1 column, 2nd subplot
    
            % Create time vector in minutes aligned with the data
            time_minutes = (0:Nframes-1) / sampling_rate / 60;
    
            % Plot raw data for the first 10 neurons
            plot(time_minutes, DF(1:min(10, size(DF, 1)), :)');  % Transpose for proper plotting
            
            % Customize the plot
            title('Données brutes des 10 premiers neurones (axe X en minutes)', 'FontSize', 14);
            ylabel('Activité', 'FontSize', 12);
            xlabel('Temps (minutes)', 'FontSize', 12);
            xlim([min(time_minutes), max(time_minutes)]);  % Align X-axis with the data
            grid on;
    
            % Third subplot: Maximum pairwise correlation for the first 10 neurons
            subplot(3, 1, 3);  % 3 rows, 1 column, 3rd subplot
    
            % Limit the analysis to the first 10 neurons
            num_cells = min(10, NCell);  % Use the minimum of 10 or the number of available cells
            max_corr_values = zeros(num_cells, num_cells);  % Pairwise max correlations
            max_lag = round(sampling_rate * 2);             % Maximum lag (2 seconds window)
    
            % Compute pairwise correlations for the first 10 neurons
            for i = 1:num_cells
                for j = i+1:num_cells
                    [cross_corr, lags] = xcorr(DF(i, :), DF(j, :), max_lag, "coeff");
                    
                    % Find maximum correlation
                    max_corr = max(cross_corr);
                    
                    % Store results in a symmetric matrix
                    max_corr_values(i, j) = max_corr;
                    max_corr_values(j, i) = max_corr;  % Symmetric matrix
                end
            end
    
            % Set diagonal elements to NaN (avoid self-correlation)
            max_corr_values(eye(num_cells, num_cells) == 1) = NaN;
    
            % Calculate the mean of off-diagonal elements
            mean_max_corr_values = nanmean(max_corr_values(:), "all");
    
            % Display the max correlation matrix as a heatmap
            imagesc(max_corr_values);  % Display correlation matrix as an image
            colorbar;                  % Add colorbar
            colormap(jet);             % Use jet colormap for better visibility
            clim([0, 1]);             % Correlation coefficients range from 0 to 1
    
            % Customize the heatmap
            title('Max Pairwise Correlation (10 premiers neurones)', 'FontSize', 14);
            xlabel('Neurones', 'FontSize', 12);
            ylabel('Neurones', 'FontSize', 12);
            axis square;               % Make the axes square for better visualization
            % Store the mean correlation for later plotting
            mean_max_corr_all(m) = mean_max_corr_values;

        catch ME
            % Display error message if something goes wrong
            fprintf('Error processing group %d: %s\n', m, ME.message);
        end
    end
    
    % After the loop, create a new figure for the bar plots
    % Mean max correlations for each group
    figure;
    bar(mean_max_corr_all);
    title('Moyenne des corrélations maximales');
    xlabel('Animaux', 'FontSize', 12);
    ylabel('Corrélation maximale moyenne', 'FontSize', 12);
    
    % Returning mean frequency per minute and its standard deviation
    return;
end
