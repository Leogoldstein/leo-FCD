function plot_F_and_DF_selected(all_F, all_DF, all_thresholds, all_Acttmp2, sampling_rate, current_animal_group, current_ages_group, cell_indices, neighbor_range) 

    if nargin < 8
        error('Vous devez spécifier cell_indices.');
    end
    if nargin < 9
        neighbor_range = 0;
    end

    if isnumeric(cell_indices)
        cell_indices = cell_indices(:)';  
    elseif iscell(cell_indices)
        cell_indices = cell_indices{1};
        cell_indices = cell_indices(:)';
    else
        error('cell_indices doit être un vecteur numérique ou une cell contenant des indices.');
    end

    for idx = 1:length(all_DF)
        if isempty(all_DF{idx}) || isempty(all_F{idx})
            continue;
        end

        DF = all_DF{idx};
        F = all_F{idx};
        thresholds = all_thresholds{idx};  
        Acttmp2 = all_Acttmp2{idx};
        [num_cells, ~] = size(DF);

        Nz = size(F,2);
        frequency = zeros(1, num_cells);
        for i = 1:num_cells
            frequency(i) = numel(Acttmp2{i}) / Nz * sampling_rate;
        end

        for c = 1:length(cell_indices)
            target_cell = cell_indices(c);
            start_idx = max(1, target_cell - neighbor_range);
            end_idx = min(num_cells, target_cell + neighbor_range);

            figure;

            % -----------------------
            % Subplot 1: F
            % -----------------------
            subplot(2,2,1);
            hold on;
            vertical_offset = 0;
            for cell_idx = start_idx:end_idx
                if cell_idx == target_cell
                    color = 'r';
                else
                    color = 'k';
                end
                plot(F(cell_idx, :) + vertical_offset, '-', 'Color', color);
                text(0, vertical_offset + max(F(cell_idx,:))/2, num2str(cell_idx), ...
                     'Color', color, 'FontWeight', 'bold', 'HorizontalAlignment', 'right');
                if cell_idx < end_idx
                    vertical_offset = vertical_offset + max(F(cell_idx, :)) * 1.2;
                end
            end
            hold off;
            xlabel('Frame Number'); ylabel('Neuron'); title('Raw Fluorescence (F)');
            xlim([1 size(F,2)]);
            yticks([]);  % Supprimer les valeurs originales de l'axe y

            % -----------------------
            % Subplot 2: DF
            % -----------------------
            subplot(2,2,2);
            hold on;
            vertical_offset = 0;
            for cell_idx = start_idx:end_idx
                if cell_idx == target_cell
                    color = 'r';
                else
                    color = 'k';
                end
                plot(DF(cell_idx, :) + vertical_offset, '-', 'Color', color);
                text(0, vertical_offset + max(DF(cell_idx,:))/2, num2str(cell_idx), ...
                     'Color', color, 'FontWeight', 'bold', 'HorizontalAlignment', 'right');
                if cell_idx < end_idx
                    vertical_offset = vertical_offset + max(DF(cell_idx, :)) * 1.2;
                end
            end
            hold off;
            xlabel('Frame Number'); ylabel('Neuron'); title('ΔF/F (DF)');
            xlim([1 size(DF,2)]);
            yticks([]);  % Supprimer les valeurs originales de l'axe y

            % -----------------------
            % Subplot 3: Threshold Histogram
            % -----------------------
            subplot(2,2,3);
            hold on;
            hist_data = thresholds(start_idx:end_idx);
            histogram(hist_data, 20);
            th_val = thresholds(target_cell);
            yl = ylim;
            plot([th_val th_val], yl, 'r--', 'LineWidth', 2);
            hold off;
            xlabel('Threshold'); ylabel('Count'); title('Threshold Histogram');

            % -----------------------
            % Subplot 4: Frequency Histogram
            % -----------------------
            subplot(2,2,4);
            hold on;
            freq_data = frequency(start_idx:end_idx);
            histogram(freq_data, 20);
            freq_val = frequency(target_cell);
            yl = ylim;
            plot([freq_val freq_val], yl, 'r--', 'LineWidth', 2);
            hold off;
            xlabel('Frequency (Hz)'); ylabel('Count'); title('Activity Frequency Histogram');

            sgtitle(['Animal: ' current_animal_group ', Age: ' current_ages_group{idx} ...
                     ', Cells: ' num2str(start_idx) ' to ' num2str(end_idx)]);
        end
    end
end
