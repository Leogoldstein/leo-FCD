function [all_cross_corr_gcamp_gcamp, all_cross_corr_gcamp_mtor, all_cross_corr_mtor_mtor] = plot_pairwise_corr(all_DF, gcamp_output_folders, all_sampling_rate, all_DF_all, all_mtor_indices)
    
    numFolders = length(gcamp_output_folders);
    all_cross_corr_gcamp_gcamp = cell(numFolders, 1);
    all_cross_corr_gcamp_mtor = cell(numFolders, 1);
    all_cross_corr_mtor_mtor = cell(numFolders, 1);

    for m = 1:numFolders
        try
            filePath = fullfile(gcamp_output_folders{m}, 'results_corr.mat');
            if exist(filePath, 'file') == 2
                data = load(filePath);
                if isfield(data, 'cross_corr_gcamp_gcamp')
                    all_cross_corr_gcamp_gcamp{m} = data.cross_corr_gcamp_gcamp;
                else
                    all_cross_corr_gcamp_gcamp{m} = [];
                end
                if isfield(data, 'cross_corr_gcamp_mtor')
                    all_cross_corr_gcamp_mtor{m} = data.cross_corr_gcamp_mtor;
                else
                    all_cross_corr_gcamp_mtor{m} = [];
                end
                if isfield(data, 'cross_corr_mtor_mtor')
                    all_cross_corr_mtor_mtor{m} = data.cross_corr_mtor_mtor;
                else
                    all_cross_corr_mtor_mtor{m} = [];
                end
            end

            if isempty(all_cross_corr_gcamp_gcamp{m})
                disp(['Processing pairwise correlation for gcamp-gcamp in file: ', filePath]);
                DF = all_DF{m};
                [num_cells, ~] = size(DF);
                cross_corr_gcamp_gcamp = NaN(num_cells, num_cells);

                for i = 1:num_cells-1
                    for j = i+1:num_cells
                        corr_matrix = corrcoef(DF(i,:), DF(j,:));
                        cross_corr_gcamp_gcamp(i,j) = corr_matrix(1,2);
                    end
                end

                save(filePath, 'cross_corr_gcamp_gcamp');
                all_cross_corr_gcamp_gcamp{m} = cross_corr_gcamp_gcamp;
            end

            if nargin > 3 && isempty(all_cross_corr_gcamp_mtor{m})
                disp(['Processing pairwise correlation for gcamp-mtor in file: ', filePath]);
                DF_all = all_DF_all{m};
                mtor_indices = all_mtor_indices{m};
                DF_mtor = DF_all(mtor_indices,:);
                mtor_indices_logical = ismember(1:size(DF_all, 1), mtor_indices);
                DF_gcamp = DF_all(~mtor_indices_logical,:);
                
                [num_gcamp_cells, ~] = size(DF_gcamp);
                [num_mtor_cells, ~] = size(DF_mtor);
                cross_corr_gcamp_mtor = NaN(num_gcamp_cells, num_mtor_cells);

                for i = 1:num_gcamp_cells
                    for j = 1:num_mtor_cells
                        corr_matrix = corrcoef(DF_gcamp(i,:), DF_mtor(j,:));
                        cross_corr_gcamp_mtor(i,j) = corr_matrix(1,2);
                    end
                end
                
                save(filePath, 'cross_corr_gcamp_mtor', '-append');
                all_cross_corr_gcamp_mtor{m} = cross_corr_gcamp_mtor;
            end

            if nargin > 3 && isempty(all_cross_corr_mtor_mtor{m})
                disp(['Processing pairwise correlation for mtor-mtor in file: ', filePath]);
                DF_all = all_DF_all{m};
                mtor_indices = all_mtor_indices{m};
                DF_mtor = DF_all(mtor_indices,:);
                
                [num_mtor_cells, ~] = size(DF_mtor);
                cross_corr_mtor_mtor = NaN(num_mtor_cells, num_mtor_cells);

                for i = 1:num_mtor_cells-1
                    for j = i+1:num_mtor_cells
                        corr_matrix = corrcoef(DF_mtor(i,:), DF_mtor(j,:));
                        cross_corr_mtor_mtor(i,j) = corr_matrix(1,2);
                    end
                end
                
                save(filePath, 'cross_corr_mtor_mtor', '-append');
                all_cross_corr_mtor_mtor{m} = cross_corr_mtor_mtor;
            end
        
        catch ME
            disp(['An error occurred in group ', num2str(m), ': ', ME.message]);
        end
    end
end
