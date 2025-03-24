function [all_max_corr_gcamp_gcamp, all_max_corr_gcamp_mtor, all_max_corr_mtor_mtor] = plot_pairwise_corr(all_DF, gcamp_output_folders, all_sampling_rate, all_DF_all, all_mtor_indices)
    
    numFolders = length(gcamp_output_folders);
    all_max_corr_gcamp_gcamp = cell(numFolders, 1);
    all_max_corr_gcamp_mtor = cell(numFolders, 1);
    all_max_corr_mtor_mtor = cell(numFolders, 1);

    % Loop over each data group
    for m = 1:numFolders
        try
            % Define the path to the results file
            filePath = fullfile(gcamp_output_folders{m}, 'results_corr.mat');
            
            % Check if the file exists
            if exist(filePath, 'file') == 2
                data = load(filePath);
                if isfield(data, 'max_corr_gcamp_gcamp')
                    all_max_corr_gcamp_gcamp{m} = data.max_corr_gcamp_gcamp;
                else
                    all_max_corr_gcamp_gcamp{m} = [];
                end
                if isfield(data, 'max_corr_gcamp_mtor')
                    all_max_corr_gcamp_mtor{m} = data.max_corr_gcamp_mtor;
                else
                    all_max_corr_gcamp_mtor{m} = [];
                end
                if isfield(data, 'max_corr_mtor_mtor')
                    all_max_corr_mtor_mtor{m} = data.max_corr_mtor_mtor;
                else
                    all_max_corr_mtor_mtor{m} = [];
                end
            end
            

            % Extract non-NaN correlation values
            valid_corr_values = all_max_corr_gcamp_gcamp{m}(~isnan(all_max_corr_gcamp_gcamp{m}));
            
            % Plot histogram
            figure;
            histogram(valid_corr_values, 20); % 20 bins, adjust as needed
            xlabel('Correlation Coefficient');
            ylabel('Frequency');
            title(['Histogram of Pairwise Correlations for gcamp-gcamp - Group ', num2str(m)]);
            set(gca, 'FontSize', 12);
            grid on;

            sampling_rate = all_sampling_rate{m};
            % Convert 200 ms to frames
            lag_200ms = round(sampling_rate * 0.2);

            % Compute pairwise correlation for gcamp-gcamp
            if isempty(all_max_corr_gcamp_gcamp{m})
                disp(['Processing pairwise correlation for gcamp-gcamp in file: ', filePath]);
                DF = all_DF{m};
                  
                [num_cells, ~] = size(DF);     
    
                % Initialize upper triangle storage
                max_corr_gcamp_gcamp = NaN(num_cells, num_cells);
    
                % Compute pairwise correlation only for upper triangle
                for i = 1:num_cells-1
                    for j = i+1:num_cells
                        [cross_corr, ~] = xcorr(DF(i,:), DF(j,:), lag_200ms, 'coeff');
                        max_corr_gcamp_gcamp(i,j) = max(cross_corr);
                    end
                end
    
                % Save only the upper triangle
                save(filePath, 'max_corr_gcamp_gcamp');
                all_max_corr_gcamp_gcamp{m} = max_corr_gcamp_gcamp;
    
                % Plot heatmap of max correlations
                figure;
                imagesc(max_corr_gcamp_gcamp);
                colorbar;
                colormap jet;
                title(['Pairwise Correlation Matrix for gcamp-gcamp Group ', num2str(m)]);
                xlabel('Neuron Index');
                ylabel('Neuron Index');
                axis square;
                set(gca, 'FontSize', 12);
    
                % Close the figure after displaying
                %close(gcf);
            end

            % Compute pairwise correlation for gcamp-mtor
            if nargin > 3 && isempty(all_max_corr_gcamp_mtor{m})
                disp(['Processing pairwise correlation for gcamp-mtor in file: ', filePath]);
                DF_all = all_DF_all{m};
                mtor_indices = all_mtor_indices{m};
                DF_mtor = DF_all(mtor_indices,:);    % Data for mtor cells
                mtor_indices_logical = ismember(1:size(DF_all, 1), mtor_indices);
                DF_gcamp = DF_all(~mtor_indices_logical,:);   % Data for non-mtor cells
  
                [num_gcamp_cells, ~] = size(DF_gcamp);
                [num_mtor_cells, ~] = size(DF_mtor);
                
                % Initialize storage for max correlations
                max_corr_gcamp_mtor = NaN(num_gcamp_cells, num_mtor_cells);

                % Compute pairwise correlation between gcamp and mtor cells
                for i = 1:num_gcamp_cells
                    for j = 1:num_mtor_cells
                        [cross_corr, ~] = xcorr(DF_gcamp(i,:), DF_mtor(j,:), lag_200ms, 'coeff');
                        max_corr_gcamp_mtor(i,j) = max(cross_corr);
                    end
                end
                
                % Save the correlations
                save(filePath, 'max_corr_gcamp_mtor', '-append');
                all_max_corr_gcamp_mtor{m} = max_corr_gcamp_mtor;

                % Plot heatmap of gcamp-mtor correlations
                figure;
                imagesc(max_corr_gcamp_mtor);
                colorbar;
                colormap jet;
                title(['Pairwise Correlation Matrix for gcamp-mtor Group ', num2str(m)]);
                xlabel('gcamp Neuron Index');
                ylabel('mtor Neuron Index');
                axis square;
                set(gca, 'FontSize', 12);

                % Close the figure after displaying
                %close(gcf);

            elseif nargin > 3 && isempty(all_max_corr_mtor_mtor{m})
                disp(['Processing pairwise correlation for mtor-mtor in file: ', filePath]);
                DF_all = all_DF_all{m};
                mtor_indices = all_mtor_indices{m};
                DF_mtor = DF_all(mtor_indices,:);    % Data for mtor cells

                [num_mtor_cells, ~] = size(DF_mtor);
                
                % Initialize storage for max correlations
                max_corr_mtor_mtor = NaN(num_mtor_cells, num_mtor_cells);

                % Compute pairwise correlation only for upper triangle
                for i = 1:num_mtor_cells-1
                    for j = i+1:num_mtor_cells
                        [cross_corr, ~] = xcorr(DF_mtor(i,:), DF_mtor(j,:), lag_200ms, 'coeff');
                        max_corr_mtor_mtor(i,j) = max(cross_corr);
                    end
                end
                
                % Save the correlations
                save(filePath, 'max_corr_mtor_mtor', '-append');
                all_max_corr_mtor_mtor{m} = max_corr_mtor_mtor;

                % Plot heatmap of mtor-mtor correlations
                figure;
                imagesc(max_corr_mtor_mtor);
                colorbar;
                colormap jet;
                title(['Pairwise Correlation Matrix for mtor-mtor Group ', num2str(m)]);
                xlabel('mtor Neuron Index');
                ylabel('mtor Neuron Index');
                axis square;
                set(gca, 'FontSize', 12);

                % Close the figure after displaying
                %close(gcf);
            end

        catch ME
            disp(['An error occurred in group ', num2str(m), ': ', ME.message]);
        end
    end
end
