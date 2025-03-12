function plot_raster(date_group_paths, all_MAct, all_Raster, all_MAct_blue, all_Raster_blue)
    % Loop through each date group
    for m = 1:length(date_group_paths)
        try
            % Retrieve MAct and Raster for the current group (normal and blue versions)
            MAct = all_MAct{m}; 
            Raster = all_Raster{m};
            MAct_blue = all_MAct_blue{m};
            Raster_blue = all_Raster_blue{m};

            % Calculate the number of cells
            [NCell, ~] = size(Raster);

            % Calculate the proportion of max cell activity
            prop_MAct = MAct / NCell; % Proportion of max activity

            % Calculate the proportion of max cell activity for the blue version
            prop_MAct_blue = MAct_blue / NCell; % Proportion of max activity (blue)

            % Plot the results for the current group
            figure('Units', 'normalized', 'OuterPosition', [0 0 1 1]);

            % First column of subplots: Raster (using imagesc)
            subplot(2, 2, 1); % First subplot: Raster for the normal case
            imagesc(Raster); % Display the Raster matrix as an image
            colormap(gray); % Use gray colormap for binary spike data (black and white)
            xlabel('Time');
            ylabel('Cell');
            title(['Raster Plot of Race Data - Group ', num2str(m)]);
            colorbar; % Add color bar to indicate binary values (0 or 1)
            axis tight; % Tighten axis limits to fit the data
            xlim([1 size(Raster, 2)]); % Set x-axis limits to the number of time steps
            ylim([1 size(Raster, 1)]); % Set y-axis limits to the number of cells

            % Second column of subplots: Raster for the blue case
            subplot(2, 2, 2); % Second subplot: Raster for the blue case
            imagesc(Raster_blue); % Display the Raster matrix as an image
            colormap(gray); % Use gray colormap for binary spike data (black and white)
            xlabel('Time');
            ylabel('Cell');
            title(['Raster Plot of Race Data (Blue) - Group ', num2str(m)]);
            colorbar; % Add color bar to indicate binary values (0 or 1)
            axis tight; % Tighten axis limits to fit the data
            xlim([1 size(Raster_blue, 2)]); % Set x-axis limits to the number of time steps
            ylim([1 size(Raster_blue, 1)]); % Set y-axis limits to the number of cells

            % Third column of subplots: Proportion of Max Cell Activity for the normal case
            subplot(2, 2, 3); % Third subplot: Proportion of Max Cell Activity for the normal case
            plot(prop_MAct, 'LineWidth', 2); % Plot the proportion of max cell activity
            xlabel('Time Frames');
            ylabel('Proportion of Max Cell Activity');
            title(['Proportion of Max Cell Activity - Group ', num2str(m)]);
            xlim([1 length(MAct)]); % Set x-axis limits based on MAct length

            % Fourth column of subplots: Proportion of Max Cell Activity for the blue case
            subplot(2, 2, 4); % Fourth subplot: Proportion of Max Cell Activity for the blue case
            plot(prop_MAct_blue, 'LineWidth', 2); % Plot the proportion of max cell activity (blue case)
            xlabel('Time Frames');
            ylabel('Proportion of Max Cell Activity');
            title(['Proportion of Max Cell Activity (Blue) - Group ', num2str(m)]);
            xlim([1 length(MAct_blue)]); % Set x-axis limits based on MAct_blue length
        catch ME
            % Handle any errors in the try block (e.g., missing data)
            fprintf('Error processing group %d: %s\n', m, ME.message);
        end
    end
end
