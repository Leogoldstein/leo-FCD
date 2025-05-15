function data_checking(all_DF, all_isort1, all_MAct, gcamp_output_folders, current_animal_group, current_ages_group, meanImgs, outline_gcampx_all, outline_gcampy_all, gcamp_props_all)
    % Visualisation améliorée : raster, traces lisibles, GCaMP en figure séparée

    function [min_val, max_val] = calculate_scaling(data)
        flattened_data = data(:);
        min_val = prctile(flattened_data, 5);   % 5ème percentile
        max_val = prctile(flattened_data, 99.9); % 99.9ème percentile
    
        % Assurer que min_val est inférieur à max_val
        if min_val >= max_val
            warning('Les limites de mise à léchelle calculées sont invalides. Ajustement aux valeurs par défaut.');
            min_val = min(flattened_data);
            max_val = max(flattened_data);
        end
    end

    for m = 1:length(gcamp_output_folders)
        try
            DF = all_DF{m};
            isort1 = all_isort1{m};

            valid_neurons = all(~isnan(DF), 2);
            DF = DF(valid_neurons, :);
            valid_neuron_indices = find(valid_neurons);
            isort1 = isort1(ismember(isort1, valid_neuron_indices));
            [~, isort1] = ismember(isort1, valid_neuron_indices);

            batch_size = 50;
            total_neurons = length(isort1);
            num_batches = ceil(total_neurons / batch_size);
            num_columns = size(DF, 2);

            % Figure principale
            figure;
            screen_size = get(0, 'ScreenSize');
            set(gcf, 'Position', screen_size);

            % Subplot 1: Raster
            ax1 = subplot('Position', [0.1, 0.75, 0.85, 0.15]);
            imagesc(ax1, DF(isort1, :));
            [minValue, maxValue] = calculate_scaling(DF);
            caxis(ax1, [minValue, maxValue]);
            colormap(ax1, 'hot');
            axis(ax1, 'tight');
            tick_step = 1000;
            tick_positions = 0:tick_step:num_columns;
            tick_labels = sprintfc('%d', tick_positions);
            ax1.XTick = tick_positions;
            ax1.XTickLabel = tick_labels;
            title(ax1, 'Sorted Rasterplot');
            ylabel(ax1, 'Neurons');
            xlabel(ax1, 'Frames');
            xlim(ax1, [0 num_columns]);
            set(ax1, 'YDir', 'normal'); % Pour que l'indice neuronale soit croissant vers le haut

            % Ajouter axe y droit avec indices neurones du batch (sera mis à jour par slider)
            ax1_right = axes('Position', ax1.Position, 'YAxisLocation', 'right', ...
                            'Color', 'none', 'XTick', [], 'Box', 'off');
            ax1_right.YDir = 'normal';
            ax1_right.XLim = ax1.XLim;

            % Subplot 2: Traces
            ax2 = subplot('Position', [0.1, 0.25, 0.85, 0.45]);

            % Subplot 3: Proportion cellules actives
            MAct = all_MAct{m};
            NCell = size(DF, 1);
            ax3 = subplot('Position', [0.1, 0.05, 0.85, 0.15]);

            % Slider
            slider_handle = uicontrol('Style', 'slider', ...
                'Min', 1, 'Max', num_batches, 'Value', 1, ...
                'SliderStep', [1/(max(num_batches-1,1)), 1/(max(num_batches-1,1))], ...
                'Units', 'normalized', ...
                'Position', [0.1 0.21 0.85 0.02], ...
                'Callback', @(src, ~) update_batch_display(src, DF, isort1, batch_size, num_columns, ax1, ax1_right, ax2, ax3, meanImgs, outline_gcampx_all, outline_gcampy_all, gcamp_props_all, MAct, NCell, m));

            linkaxes([ax1, ax2, ax3], 'x');

            sgtitle(sprintf('%s – %s', current_animal_group, current_ages_group{m}), 'FontWeight', 'bold');

            % Initial update to show batch 1
            update_batch_display(slider_handle, DF, isort1, batch_size, num_columns, ax1, ax1_right, ax2, ax3, meanImgs, outline_gcampx_all, outline_gcampy_all, gcamp_props_all, MAct, NCell, m);

        catch ME
            fprintf('\nError: %s\n', ME.message);
        end
    end
end

function update_batch_display(slider_handle, DF, isort1, batch_size, num_columns, ax1, ax1_right, ax2, ax3, meanImgs, outline_gcampx_all, outline_gcampy_all, gcamp_props_all, MAct, NCell, m)
    batch_index = round(get(slider_handle, 'Value'));
    start_idx = (batch_index - 1) * batch_size + 1;
    end_idx = min(batch_index * batch_size, length(isort1));
    neurons_in_batch = isort1(start_idx:end_idx);

    % Subplot 2: Traces dans l'ordre normal (ordre croissant)
    cla(ax2); hold(ax2, 'on');
    vertical_offset = 0;
    yticks_pos = [];
    yticklabels_list = [];
    
    for i = 1:length(neurons_in_batch)
        cellIndex = neurons_in_batch(i);
        trace = DF(cellIndex, :);
        plot(ax2, trace + vertical_offset, 'k', 'LineWidth', 0.5);
        yticks_pos(end+1) = vertical_offset + max(trace)/2;
        yticklabels_list{end+1} = num2str(cellIndex);
        vertical_offset = vertical_offset + max(trace) * 1.2;
    end
    
    xlabel(ax2, 'Frame');
    title(ax2, sprintf('Sorted Cell Traces – Batch %d', batch_index));
    xlim(ax2, [0 num_columns]);
    ax2.YTick = yticks_pos;
    ax2.YTickLabel = yticklabels_list;
    axis(ax2, 'tight');
    grid(ax2, 'on');
    hold(ax2, 'off');


    xlabel(ax2, 'Frame');
    title(ax2, sprintf('Sorted Cell Traces – Batch %d', batch_index));
    xlim(ax2, [0 num_columns]);
    ax2.YTick = yticks_pos;
    ax2.YTickLabel = yticklabels_list;
    axis(ax2, 'tight');
    grid(ax2, 'on');
    hold(ax2, 'off');

    % Subplot 1 : Raster + rectangle batch
    cla(ax1);
    imagesc(ax1, DF(isort1, :));
    caxis(ax1, [prctile(DF(:), 5), prctile(DF(:), 99.9)]);
    colormap(ax1, 'hot');
    axis(ax1, 'tight');
    ax1.XTick = 0:1000:num_columns;
    ax1.XTickLabel = arrayfun(@num2str, 0:1000:num_columns, 'UniformOutput', false);
    xlim(ax1, [0 num_columns]);
    ylabel(ax1, 'Neurons');
    xlabel(ax1, 'Frames');
    set(ax1, 'YDir', 'normal');

    % Ajouter rectangle sur ax1 pour batch courant
    hold(ax1, 'on');
    y_start = start_idx - 0.5;
    y_height = length(neurons_in_batch);
    rectangle(ax1, 'Position', [0, y_start, num_columns, y_height], 'EdgeColor', 'c', 'LineWidth', 1.5);
    hold(ax1, 'off');

    % Mettre à jour axe y droit avec indices neurones batch courant
    cla(ax1_right);
    ax1_right.YLim = ax1.YLim;
    ax1_right.XLim = ax1.XLim;
    ax1_right.YTick = (start_idx):(end_idx);
    ax1_right.YTickLabel = arrayfun(@num2str, neurons_in_batch, 'UniformOutput', false);
    ax1_right.XTick = [];
    ax1_right.YDir = 'normal';
    ylabel(ax1_right, 'Batch Neuron IDs');

    % Subplot 3 : Proportion cellules actives
    cla(ax3);
    prop_MAct = MAct / NCell;
    plot(ax3, prop_MAct, 'LineWidth', 2);
    xlabel(ax3, 'Frame');
    ylabel(ax3, 'Proportion of Active Cells');
    title(ax3, 'Activity Over Consecutive Frames');
    xlim(ax3, [0 num_columns]);
    grid(ax3, 'on');

    % GCaMP outlines (dans une autre figure)
    figure_handle = findobj('Type', 'figure', 'Name', 'GCaMP Figure');
    if isempty(figure_handle)
        figure_handle = figure('Name', 'GCaMP Figure');
    else
        figure(figure_handle);
    end
    clf(figure_handle);
    hold on;

    meanImg = meanImgs{m};
    outline_gcampx = outline_gcampx_all{m};
    outline_gcampy = outline_gcampy_all{m};
    gcamp_props = gcamp_props_all{m};

    imagesc(meanImg);
    colormap(gca, gray);
    axis image;

    for n = 1:length(neurons_in_batch)
        idx = neurons_in_batch(n);

        if idx <= length(outline_gcampx) && idx <= length(outline_gcampy)
            plot(outline_gcampx{idx}, outline_gcampy{idx}, '.', 'MarkerSize', 1, 'Color', 'g');
            % Annoter avec l'indice réel du neurone
            text(max(outline_gcampx{idx}), max(outline_gcampy{idx}), num2str(idx), 'FontSize', 10, 'Color', 'w');
        end
    end

    title(sprintf('GCaMP outlines – Batch %d', batch_index));
    xlabel('X Coordinate');
    ylabel('Y Coordinate');
    set(gca, 'YDir', 'reverse');
    hold off;
end
