function plot_threshold_sce_evolution1(all_DF, directories, animal_date_list, fractions, NShfl, synchronous_frames, MinPeakDistance, MinPeakDistancesce)
    % Function to detect and plot thresholds for SCEs with varying neuron fractions
    %
    % Inputs:
    % - all_DF: Cell array containing DF matrices for each dataset
    % - directories: Cell array of output directories for saving figures
    % - animal_date_list: Cell array containing the animal and date parts for naming figures
    % - fractions: Array of fractions to use for calculating thresholds
    % - NShfl: Number of shuffles for threshold calculation
    % - synchronous_frames: Number of frames used for synchronous event detection
    % - MinPeakDistance: Minimum distance between peaks for MAct calculation
    % - MinPeakDistancesce: Minimum distance between peaks for SCE detection

    for k = 1:length(directories)
        try
            % Check if the index k is valid
            if k > length(all_DF) || k > length(animal_date_list) || k > length(directories)
                error('Index %d exceeds the number of elements in one of the input arrays.', k);
            end

            % Extract data for the current folder
            DF = all_DF{k};
            animal_part = animal_date_list{k,1};
            date_part = animal_date_list{k,2};

            [NCell, Nz] = size(DF);

            % Initialize arrays to store thresholds and number of SCEs
            thresholds = zeros(length(fractions), 1);
            num_sces = zeros(length(fractions), 1);

            % Loop through each fraction to calculate threshold and detect SCEs
            for f = 1:length(fractions)
                fraction = fractions(f);
                num_cells_fraction = round(NCell * fraction);

                % Check if the fraction is valid
                if num_cells_fraction < 1
                    error('Fraction %f results in fewer than 1 neuron, which is invalid.', fraction);
                end

                % Extract the subset of DF for the current fraction
                DF_fraction = DF(1:num_cells_fraction, :);

                % Recalculate Raster and MAct for the current fraction
                [Raster_fraction, MAct_fraction] = Sumactivity(DF_fraction, MinPeakDistance, synchronous_frames);

                % Shuffle and calculate thresholds
                Sumactsh = zeros(Nz - synchronous_frames, NShfl);
                for n = 1:NShfl
                    Rastersh = Raster_fraction;
                    for c = 1:num_cells_fraction
                        k_shift = randi(Nz - synchronous_frames);
                        Rastersh(c,:) = circshift(Rastersh(c,:), k_shift, 2);
                    end

                    MActsh = zeros(1, Nz - synchronous_frames);
                    for i = 1:(Nz - synchronous_frames)
                        MActsh(i) = sum(max(Rastersh(:,i:i+synchronous_frames), [], 2));
                    end

                    Sumactsh(:, n) = MActsh;
                end

                percentile = 99; % 99th percentile for threshold
                thresholds(f) = prctile(Sumactsh(:), percentile);

                % Detect SCEs with the calculated threshold
                [~, TRace] = findpeaks(MAct_fraction(:), 'MinPeakHeight', thresholds(f), 'MinPeakDistance', MinPeakDistancesce);
                num_sces(f) = length(TRace);
            end

            save(fullfile (directories{k}, 'SCEs_evolution.mat'), 'num_sces', 'num_cells_fraction');

            % Plot the results
            figure;
            hold on;

            % Plot thresholds on the left y-axis
            yyaxis left;
            plot(fractions * NCell, thresholds, 'b-o', 'LineWidth', 2);
            ylabel('Threshold for SCE Detection');
            xlabel('Number of Neurons');
            title(sprintf('SCE Detection Thresholds and Counts for %s (%s)', animal_part, date_part));
            xlim([0 NCell]);
            ylim([0 max(thresholds) * 1.1]); % Adjust y-axis limit to fit thresholds
            grid on;

            % Create a second y-axis for the number of SCEs
            yyaxis right;
            plot(fractions * NCell, num_sces, 'r-o', 'LineWidth', 2);
            ylabel('Number of SCEs');

            % Adjust y-axis limit for number of SCEs
            max_sces = max(num_sces);
            ylim([0 max_sces * 1.1]); % Adjust y-axis limit to fit number of SCEs

            % Add legend
            legend('Detection Thresholds', 'Number of SCEs', 'Location', 'best');
            hold off;

            % Save the figure
            fig_name = sprintf('SCE Detection as a function of number of cells (%s %s)', animal_part, date_part);
            save_path = fullfile(directories{k}, [fig_name, '.png']);
            saveas(gcf, save_path);
            close(gcf);

        catch ME
            disp(['Error processing folder ' num2str(k) ': ' ME.message]);
        end
    end
end
