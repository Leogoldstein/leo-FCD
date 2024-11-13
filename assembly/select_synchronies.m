function [all_sce_n_cells_threshold, all_Race, all_RasterRace] = select_synchronies(directories, all_DF, MinPeakDistancesce, all_Raster, all_MAct, animal_date_list, synchronous_frames, WinActive)
    % select_synchronies processes data from multiple folders, detecting synchronies (SCEs),
    % creating raster plots, and saving the results.
    %
    % Inputs:
    % - directories: Cell array of directories to save the results
    % - all_DF: Cell array of dF/F traces for each folder
    % - all_MAct: Cell array of sum of max cell activities for each folder
    % - MinPeakDistance: Minimum distance between peaks in frames
    % - all_Raster: Cell array of raster data for each folder
    % - animal_date_list: Cell array with animal and date information for file naming
    % - save_directory: Directory to save the results
    %
    % Outputs:
    % - all_Race: Cell array containing Race matrices for each folder
    % - all_RasterRace: Cell array containing RasterRace matrices for each folder

    % Initialize cell arrays to store Race and RasterRace for each folder
    all_Race = cell(1, length(directories));
    all_RasterRace = cell(1, length(directories));
    all_sce_n_cells_threshold = cell(1, length(directories));

    % Loop through each file path
    for k = 1:length(directories)
        try
            % Extract data for the current folder
            DF = all_DF{k};
            MAct = all_MAct{k};
            Raster = all_Raster{k};

            [NCell, Nz] = size(DF);

            % Select synchronies (SCEs)
            
            %%%%shuffling to find threshold for number of cell for sce detection
            MActsh = zeros(1,Nz-synchronous_frames);   
            Rastersh=zeros(NCell,Nz);   
            NShfl=100;
            Sumactsh=zeros(Nz-synchronous_frames,NShfl);   
            for n=1:NShfl

                for c=1:NCell
                    l = randi(Nz-length(WinActive));
                    Rastersh(c,:)= circshift(Raster(c,:),l,2);
                end

                for i=1:Nz-synchronous_frames   %need to use WinRest???
                    MActsh(i) = sum(max(Rastersh(:,i:i+synchronous_frames),[],2));
                end

                Sumactsh(:,n)=MActsh;

            end
            % toc
            percentile = 99; % Calculate the 5% highest point or 99
            sce_n_cells_threshold = prctile(Sumactsh, percentile,"all");
            % sce_n_cells_threshold =10;
            
            disp(['sce_n_cells_threshold: ' num2str(sce_n_cells_threshold)])
            %sce_n_cells_threshold = 5;
            %sce_n_cells_threshold =median(Sumactsh,'all');
            %sce_n_cells_threshold =3*iqr(Sumactsh,'all');    


            % Threshold for number of cells for SCE detection
            %sce_n_cells_threshold = 20;  % This value can be adjusted or calculated dynamically
            
            % Select synchronies (SCEs)
            [~, TRace] = findpeaks(MAct, 'MinPeakHeight', sce_n_cells_threshold, 'MinPeakDistance', MinPeakDistancesce);
            NRace = length(TRace);
            disp(['nSCE: ' num2str(NRace)])

            % Create Race and RasterRace matrices
            all_sce_n_cells_threshold{k} = sce_n_cells_threshold;
            Race = zeros(NCell, NRace);
            RasterRace = zeros(NCell, Nz);

            for i = 1:NRace
                start_idx = max(TRace(i) - 1, 1);
                end_idx = min(TRace(i) + 2, Nz);
                Race(:, i) = max(Raster(:, start_idx:end_idx), [], 2);
                RasterRace(Race(:, i) == 1, TRace(i)) = 1;
            end
            
            % Store the Race and RasterRace matrices
            all_Race{k} = Race;
            all_RasterRace{k} = RasterRace;

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

            % Generate the figure name using animal_part and date_part
            animal_part = animal_date_list{k, 3};
            date_part = animal_date_list{k, 4};
            fig_name = sprintf('Raster_plot_of_Race_data_of_%s_%s', animal_part, date_part);

            % Save the figure
            save_path = fullfile(directories{k}, [fig_name, '.png']);
            saveas(gcf, save_path);
            close(gcf);

            % Save all variables to .mat files for the current folder
            save(fullfile(directories{k}, 'results_SCEs.mat'), 'Race', 'TRace', 'RasterRace', 'sce_n_cells_threshold');

        catch ME
            warning('Error processing folder %s: %s', directories{k}, ME.message);
        end
    end
end