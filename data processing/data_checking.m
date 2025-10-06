function [selected_neurons_ordered, selected_gcamp_neurons_original, selected_blue_neurons_original, suite2p] = data_checking(data, gcamp_output_folders, current_gcamp_folders_group, current_animal_group, current_dates_group, current_ages_group, meanImgs_gcamp, checking_choice2)
    
    % Initialisation du tableau de résultats (sélections par dossier)
    selected_neurons_ordered = cell(size(gcamp_output_folders));
    selected_gcamp_neurons_original = cell(size(gcamp_output_folders));
    suite2p = false;
    
    for m = 1:length(gcamp_output_folders)
        switch checking_choice2
            case '1'
                F = data.F_gcamp{m};
                DF = data.DF_gcamp{m};
                isort1 = data.isort1_gcamp{m};
                MAct = data.MAct_gcamp{m};
                blue_indices = [];
                batch_size = 30;

            case '2'
                F = data.F_blue{m};
                DF = data.DF_blue{m};
                isort1 = [];
                MAct = data.MAct_blue{m};
                blue_indices = [];
                batch_size = 5;
                
            case '3'
                F = data.F_combined{m};
                DF = data.DF_combined{m};
                isort1 = data.isort1_combined{m};
                MAct = data.MAct_combined{m};
                blue_indices = data.blue_indices_combined{m};
                batch_size = 30;
        end

        % --- Nettoyer NaN ---
        valid_neurons = any(~isnan(DF), 2);
        DF = DF(valid_neurons, :);
        DF(isnan(DF)) = 0;
        valid_neuron_indices = find(valid_neurons);
        
        % --- Gérer isort1 vide ---
        if isempty(isort1)
            % Pas d'ordre spécifique → garder l'ordre naturel
            isort1 = 1:size(DF, 1);
        else
            % Filtrer et réindexer normalement
            isort1 = isort1(ismember(isort1, valid_neuron_indices));
            [~, isort1] = ismember(isort1, valid_neuron_indices);
        end

        total_neurons = length(isort1);
        num_batches = ceil(total_neurons / batch_size);
        num_columns = size(DF, 2);

        % --- Figure principale ---
        main_fig = figure;
        screen_size = get(0, 'ScreenSize');
        set(main_fig, 'Position', screen_size);

        ax1 = subplot('Position', [0.1, 0.75, 0.85, 0.15]);
        ax1_right = axes('Position', ax1.Position, 'YAxisLocation', 'right', ...
            'Color', 'none', 'XTick', [], 'Box', 'off');
        ax1_right.YDir = 'normal';
        ax1_right.XLim = ax1.XLim;
        ax2 = subplot('Position', [0.1, 0.25, 0.85, 0.45]);
        ax3 = subplot('Position', [0.1, 0.05, 0.85, 0.15]);

        NCell = size(F, 1);
        prop_MAct = MAct / NCell;
        plot(ax3, prop_MAct, 'LineWidth', 2);
        xlabel(ax3, 'Frame');
        ylabel(ax3, 'Proportion of Active Cells');
        title(ax3, 'Activity Over Consecutive Frames');
        try xlim(ax3, [1 num_columns]); catch; end
        grid(ax3, 'on');

        % --- Slider ---
        slider_handle = uicontrol('Style', 'slider', ...
            'Min', 1, 'Max', num_batches, 'Value', 1, ...
            'SliderStep', [1/(max(num_batches-1,1)), 1/(max(num_batches-1,1))], ...
            'Units', 'normalized', 'Position', [0.1 0.21 0.85 0.02]);

        % --- Figure GCaMP / Blue ---
        gcamp_fig = figure('Name', 'Neuron Visualization');
        setappdata(gcamp_fig, 'checking_choice2', checking_choice2);
        setappdata(gcamp_fig, 'meanImg', meanImgs_gcamp{m});
        setappdata(gcamp_fig, 'selected_neurons_total', []);
        setappdata(gcamp_fig, 'neurons_in_batch', []);
        setappdata(gcamp_fig, 'output_index', m);
        setappdata(gcamp_fig, 'parent_figure', main_fig);
        setappdata(gcamp_fig, 'blue_indices', blue_indices);
        setappdata(gcamp_fig, 'current_gcamp_folder', current_gcamp_folders_group{m});
        
        % Charger uniquement les outlines nécessaires selon le choix
        switch checking_choice2
            case '1' % GCaMP uniquement
                setappdata(gcamp_fig, 'outline_gcampx', data.outlines_gcampx{m});
                setappdata(gcamp_fig, 'outline_gcampy', data.outlines_gcampy{m});
        
            case '2' % Blue avec GCaMP (cellpose uniquement)
                setappdata(gcamp_fig, 'outline_cellposex', data.outlines_x_cellpose{m});
                setappdata(gcamp_fig, 'outline_cellposey', data.outlines_y_cellpose{m});
        
            case '3' % Les deux
                setappdata(gcamp_fig, 'outline_gcampx', data.outlines_gcampx{m});
                setappdata(gcamp_fig, 'outline_gcampy', data.outlines_gcampy{m});
                setappdata(gcamp_fig, 'outline_cellposex', data.outlines_x_cellpose{m});
                setappdata(gcamp_fig, 'outline_cellposey', data.outlines_y_cellpose{m});
        end

        % --- Boutons ---
        uicontrol('Parent', gcamp_fig, 'Style', 'pushbutton', ...
            'String', 'Inspecter les traces sélectionnées', ...
            'Units', 'normalized', 'Position', [0.70, 0.01, 0.13, 0.05], ...
            'Callback', @(~,~) inspect_traces_callback(gcamp_fig, data, m, ...
                current_animal_group, current_ages_group));


        uicontrol('Parent', gcamp_fig, 'Style', 'pushbutton', ...
            'String', 'Suivant', 'Units', 'normalized', ...
            'Position', [0.8 0.95 0.15 0.04], ...
            'Callback', @(~,~) validate_selection(gcamp_fig, ...
                getappdata(gcamp_fig,'output_index'), ...
                getappdata(gcamp_fig,'current_gcamp_folder')));

        uicontrol('Parent', gcamp_fig, 'Style', 'pushbutton', ...
            'String', 'Masquer traces', 'Units', 'normalized', ...
            'Position', [0.55, 0.01, 0.13, 0.05], ...
            'Callback', @(src,~) toggle_traces_display(gcamp_fig, src));

        % --- Callback slider ---
        slider_handle.Callback = @(src, ~) update_batch_display(slider_handle, F, DF, isort1, batch_size, ...
            num_columns, ax1, ax1_right, ax2, meanImgs_gcamp, MAct, blue_indices, ...
            NCell, m, data, gcamp_fig, valid_neuron_indices);

        linkaxes([ax1, ax2, ax3], 'x');
        sgtitle(main_fig, ...
                sprintf('%s – %s - %s', current_animal_group, current_dates_group{m}, current_ages_group{m}), ...
                'FontWeight', 'bold');

       % --- Affichage initial ---
        update_batch_display(slider_handle, F, DF, isort1, batch_size, num_columns, ...
             ax1, ax1_right, ax2, meanImgs_gcamp, MAct, blue_indices, NCell, m, data, gcamp_fig, valid_neuron_indices);

        % --- Récupérer résultats ---
        uiwait(gcamp_fig);
        
        % --- Récupérer résultats ---
        key = sprintf('selected_result_%d', m);
        if isappdata(0, key)
            selected_neurons_ordered{m} = getappdata(0, key);
            rmappdata(0, key);  % nettoyage
        else
            selected_neurons_ordered{m} = [];
        end
        
        % Conversion en indices originaux
        if ~isempty(selected_neurons_ordered{m})
            selected_gcamp_neurons_original{m} = valid_neuron_indices(selected_neurons_ordered{m});
        else
            selected_gcamp_neurons_original{m} = [];
        end
        
        % --- Sélection des neurones bleus ---
        if ~isempty(selected_gcamp_neurons_original{m}) && ~isempty(blue_indices)
            selected_blue_neurons_original{m} = intersect(selected_gcamp_neurons_original{m}, blue_indices);
        else
            selected_blue_neurons_original{m} = [];
        end
        
        % --- Exclure les neurones bleus des neurones GCaMP classiques ---
        if ~isempty(selected_gcamp_neurons_original{m}) && ~isempty(selected_blue_neurons_original{m})
            selected_gcamp_neurons_original{m} = setdiff(selected_gcamp_neurons_original{m}, selected_blue_neurons_original{m});
        end
    end
end


function update_batch_display(slider_handle, F, DF, isort1, batch_size, num_columns, ...
                              ax1, ax1_right, ax2, meanImgs_gcamp, MAct, blue_indices, ...
                              NCell, m, data, figure_handle, valid_neuron_indices)

    % figure_handle est maintenant toujours valide, passé depuis data_checking
    if ~isvalid(figure_handle)
        error('Figure handle invalide !');
    end

    % Initialiser appdata si elles n'existent pas encore
    if ~isappdata(figure_handle, 'meanImg')
        setappdata(figure_handle, 'meanImg', meanImgs_gcamp{m});
    end
    if ~isappdata(figure_handle, 'outline_gcampx') && ~isappdata(figure_handle, 'outline_cellposex')
        switch getappdata(figure_handle, 'checking_choice2')
            case '1' % GCaMP uniquement
                setappdata(figure_handle, 'outline_gcampx', data.outlines_gcampx{m});
                setappdata(figure_handle, 'outline_gcampy', data.outlines_gcampy{m});
            
            case '2' % Blue uniquement
                setappdata(figure_handle, 'outline_cellposex', data.outlines_x_cellpose{m});
                setappdata(figure_handle, 'outline_cellposey', data.outlines_y_cellpose{m});
            
            case '3' % Les deux
                setappdata(figure_handle, 'outline_gcampx', data.outlines_gcampx{m});
                setappdata(figure_handle, 'outline_gcampy', data.outlines_gcampy{m});
                setappdata(figure_handle, 'outline_cellposex', data.outlines_x_cellpose{m});
                setappdata(figure_handle, 'outline_cellposey', data.outlines_y_cellpose{m});
        end
    end

    % Récupérer la sélection cumulée (validée)
    if isappdata(figure_handle, 'selected_neurons_total')
        selected_neurons_total = getappdata(figure_handle, 'selected_neurons_total');
    else
        selected_neurons_total = [];
    end

    % Conserver les sélections temporaires si elles existent déjà
    if isappdata(figure_handle, 'selected_neurons_gcamp')
        selected_neurons_gcamp = getappdata(figure_handle, 'selected_neurons_gcamp');
    else
        selected_neurons_gcamp = [];
    end

    if isappdata(figure_handle, 'selected_neurons_cellpose')
        selected_neurons_cellpose = getappdata(figure_handle, 'selected_neurons_cellpose');
    else
        selected_neurons_cellpose = [];
    end
    
    if ~isappdata(figure_handle, 'gcamp_colors')
        rng(42); % pour reproductibilité
        gcamp_colors = rand(length(data.outlines_gcampx{m}), 3); % une couleur par neurone
        setappdata(figure_handle, 'gcamp_colors', gcamp_colors);
    end

    % Réécrire dans appdata (inchangé si déjà existant)
    setappdata(figure_handle, 'selected_neurons_gcamp', selected_neurons_gcamp);
    setappdata(figure_handle, 'selected_neurons_cellpose', selected_neurons_cellpose);


    % Stocker dans appdata la sélection cumulée et temporaire
    setappdata(figure_handle, 'selected_neurons_total', selected_neurons_total);

    % Exclure les neurones validés de isort1 (pour ne pas les montrer)
    if isempty(selected_neurons_total)
        isort1_filtered = isort1;
    else
        isort1_filtered = setdiff(isort1, selected_neurons_total);
    end

    % Calcul du batch courant
    batch_index = round(get(slider_handle, 'Value'));
    start_idx = (batch_index - 1) * batch_size + 1;
    end_idx = min(batch_index * batch_size, length(isort1_filtered));
    neurons_in_batch = isort1_filtered(start_idx:end_idx);

    % Stocker batch courant et autres données dans appdata pour accès dans callbacks
    setappdata(figure_handle, 'neurons_in_batch', neurons_in_batch);
    setappdata(figure_handle, 'slider_handle', slider_handle);
    setappdata(figure_handle, 'F', F);
    setappdata(figure_handle, 'DF', DF);
    setappdata(figure_handle, 'isort1', isort1);
    setappdata(figure_handle, 'batch_size', batch_size);
    setappdata(figure_handle, 'num_columns', num_columns);
    setappdata(figure_handle, 'ax1', ax1);
    setappdata(figure_handle, 'ax1_right', ax1_right);
    setappdata(figure_handle, 'ax2', ax2);
    setappdata(figure_handle, 'meanImgs_gcamp', meanImgs_gcamp);
    setappdata(figure_handle, 'outlines_gcampx', data.outlines_gcampx{m});
    setappdata(figure_handle, 'outlines_gcampy', data.outlines_gcampy{m});
    setappdata(figure_handle, 'MAct', MAct);
    setappdata(figure_handle, 'NCell', NCell);
    setappdata(figure_handle, 'm', m);
    setappdata(figure_handle, 'outlines_x_cellpose', data.outlines_x_cellpose{m});
    setappdata(figure_handle, 'outlines_y_cellpose', data.outlines_y_cellpose{m});
    setappdata(figure_handle, 'blue_indices', blue_indices);
    setappdata(figure_handle, 'valid_neuron_indices', valid_neuron_indices);

    % Mise à jour des affichages
    update_gcamp_figure(figure_handle);      % affiche outlines et sélection temporaire
    update_traces_subplot(figure_handle);   % affiche traces sans neurones validés

    % Mise à jour raster ax1 (sans neurones validés)
    cla(ax1);
    DF_z = zscore(DF, [], 2);              % zscore ligne par ligne (chaque cellule)
    imagesc(ax1, DF_z(isort1_filtered, :));
    [minValue, maxValue] = calculate_scaling(DF_z);
    clim(ax1, [minValue, maxValue]);
    colormap(ax1, 'hot');
    axis(ax1, 'tight');
    ax1.XTick = 0:1000:num_columns;
    ax1.XTickLabel = arrayfun(@num2str, 0:1000:num_columns, 'UniformOutput', false);
    xlim(ax1, [0 num_columns]);
    ylabel(ax1, 'Neurons');
    xlabel(ax1, 'Frames');
    set(ax1, 'YDir', 'normal');
    hold(ax1, 'on');
    rectangle(ax1, 'Position', [0, start_idx - 0.5, num_columns, length(neurons_in_batch)], 'EdgeColor', 'c', 'LineWidth', 1.5);
    hold(ax1, 'off');

    % Axe droit ax1_right (batch neurons)
    % cla(ax1_right);
    % ax1_right.YLim = ax1.YLim;
    % ax1_right.XLim = ax1.XLim;
    % ax1_right.YTick = start_idx:end_idx;
    % ax1_right.YTickLabel = arrayfun(@num2str, neurons_in_batch, 'UniformOutput', false);
    % ax1_right.XTick = [];
    % ax1_right.YDir = 'normal';
    % ylabel(ax1_right, 'Batch Neuron IDs');
end

function update_gcamp_figure(fig_handle)
    % --- 1. Récupération des données ---
    meanImg = getappdata(fig_handle, 'meanImg');
    outline_gcampx = getappdata(fig_handle, 'outline_gcampx');
    outline_gcampy = getappdata(fig_handle, 'outline_gcampy');
    outline_cellposex = getappdata(fig_handle, 'outline_cellposex');
    outline_cellposey = getappdata(fig_handle, 'outline_cellposey');
    neurons_in_batch = getappdata(fig_handle, 'neurons_in_batch');
    valid_neuron_indices = getappdata(fig_handle, 'valid_neuron_indices');
    blue_indices = getappdata(fig_handle, 'blue_indices');
    selected_total = getappdata(fig_handle, 'selected_neurons_total');
    if isempty(selected_total), selected_total = []; end

    % --- Récupérer le mode de vérification ---
    if isappdata(fig_handle, 'checking_choice2')
        checking_choice2 = getappdata(fig_handle, 'checking_choice2');
    else
        checking_choice2 = '3'; % par défaut (les deux)
    end

    % --- 2. Axe dédié ---
    if ~isappdata(fig_handle, 'ax_gcamp')
        ax_gcamp = axes('Parent', fig_handle);
        setappdata(fig_handle, 'ax_gcamp', ax_gcamp);
    else
        ax_gcamp = getappdata(fig_handle, 'ax_gcamp');
    end

    cla(ax_gcamp);
    hold(ax_gcamp, 'on');
    imagesc(ax_gcamp, meanImg);
    colormap(ax_gcamp, gray);
    axis(ax_gcamp, 'image');
    set(ax_gcamp, 'YDir', 'reverse');
    title(ax_gcamp, 'Neuron Outlines');

    % --- 3. Vérifier le flag de masquage ---
    show_traces = true;
    if isappdata(fig_handle, 'show_selected_traces')
        show_traces = getappdata(fig_handle, 'show_selected_traces');
    end

    % --- 4. Couleurs GCaMP ---
    if ~isappdata(fig_handle, 'gcamp_colors')
        rng(42); % reproductible
        gcamp_colors = rand(length(outline_gcampx), 3);
        setappdata(fig_handle, 'gcamp_colors', gcamp_colors);
    else
        gcamp_colors = getappdata(fig_handle, 'gcamp_colors');
    end

    % --- 5. Conversion indices batch → indices originaux ---
    if isempty(valid_neuron_indices)
        neurons_in_batch_original = neurons_in_batch;
    else
        neurons_in_batch_original = valid_neuron_indices(neurons_in_batch);
    end

    % --- 6. Si batch vide, afficher tous les outlines pour vérification ---
    if isempty(neurons_in_batch_original)
        warning('⚠️ Aucun neurone dans le batch courant — affichage complet.');
        if ~isempty(outline_gcampx)
            for k = 1:length(outline_gcampx)
                plot(ax_gcamp, outline_gcampx{k}, outline_gcampy{k}, '-', 'Color', [0.6 0.6 0.6]);
            end
        end
        if ~isempty(outline_cellposex)
            for k = 1:length(outline_cellposex)
                plot(ax_gcamp, outline_cellposex{k}, outline_cellposey{k}, '-', 'Color', [0.2 0.2 1]);
            end
        end
        hold(ax_gcamp, 'off');
        return;
    end

    % --- 7. Tracé selon le mode choisi ---
    switch checking_choice2
        case '1'  % --- GCaMP uniquement ---
            if isempty(outline_gcampx)
                warning('Aucun outline GCaMP disponible.');
            else
                for n = 1:length(neurons_in_batch_original)
                    idx = neurons_in_batch_original(n);
                    if idx <= length(outline_gcampx)
                        if ~show_traces && ismember(idx, selected_total), continue; end
                        if ismember(idx, selected_total)
                            color = 'r'; lw = 2;
                        else
                            color = gcamp_colors(idx, :); lw = 1;
                        end
                        plot(ax_gcamp, outline_gcampx{idx}, outline_gcampy{idx}, '-', ...
                            'Color', color, 'LineWidth', lw, ...
                            'ButtonDownFcn', @(src, event) neuron_clicked(src, event, idx, fig_handle, 'gcamp'));
                    end
                end
            end

        case '2'  % --- Cellpose uniquement ---
            if isempty(outline_cellposex)
                warning('Aucun outline Cellpose disponible.');
            else
                for n = 1:length(neurons_in_batch_original)
                    idx = neurons_in_batch_original(n);
                    if idx <= length(outline_cellposex)
                        if ~show_traces && ismember(idx, selected_total), continue; end
                        if ismember(idx, selected_total)
                            color = [1 0 0]; lw = 2;
                        else
                            color = [0 0 1]; lw = 1;
                        end
                        plot(ax_gcamp, outline_cellposex{idx}, outline_cellposey{idx}, '-', ...
                            'Color', color, 'LineWidth', lw, ...
                            'ButtonDownFcn', @(src, event) neuron_clicked(src, event, idx, fig_handle, 'cellpose'));
                    end
                end
            end

        case '3'  % --- Les deux ---
            % Cellpose (bleu)
            for n = 1:min(length(neurons_in_batch_original), length(outline_cellposex))
                idx = neurons_in_batch_original(n);
                if idx <= length(outline_cellposex)
                    if ~show_traces && ismember(idx, selected_total), continue; end
                    if ismember(idx, selected_total)
                        color = [1 0 0]; lw = 2;
                    else
                        color = [0 0 1]; lw = 1;
                    end
                    plot(ax_gcamp, outline_cellposex{idx}, outline_cellposey{idx}, '-', ...
                        'Color', color, 'LineWidth', lw, ...
                        'ButtonDownFcn', @(src, event) neuron_clicked(src, event, idx, fig_handle, 'cellpose'));
                end
            end

            % GCaMP (vert)
            for n = 1:min(length(neurons_in_batch_original), length(outline_gcampx))
                idx = neurons_in_batch_original(n);
                if idx <= length(outline_gcampx)
                    if ~show_traces && ismember(idx, selected_total), continue; end
                    if ismember(idx, selected_total)
                        color = [1 0 0]; lw = 2;
                    else
                        color = [0 1 0]; lw = 1;
                    end
                    plot(ax_gcamp, outline_gcampx{idx}, outline_gcampy{idx}, '-', ...
                        'Color', color, 'LineWidth', lw, ...
                        'ButtonDownFcn', @(src, event) neuron_clicked(src, event, idx, fig_handle, 'gcamp'));
                end
            end
    end

    % --- 8. Finalisation ---
    hold(ax_gcamp, 'off');
end


function update_traces_subplot(main_fig_handle)
    ax2 = getappdata(main_fig_handle, 'ax2');
    F = getappdata(main_fig_handle, 'F');
    DF = getappdata(main_fig_handle, 'DF');
    neurons_in_batch = getappdata(main_fig_handle, 'neurons_in_batch');
    blue_indices = getappdata(main_fig_handle, 'blue_indices');
    num_columns = getappdata(main_fig_handle, 'num_columns');
    selected_total = getappdata(main_fig_handle, 'selected_neurons_total');

    if isempty(selected_total), selected_total = []; end

    % Gestion du toggle show/hide
    show_traces = true;
    if isappdata(main_fig_handle, 'show_selected_traces')
        show_traces = getappdata(main_fig_handle, 'show_selected_traces');
    end

    cla(ax2);
    hold(ax2, 'on');
    vertical_offset = 0;
    yticks_pos = [];
    yticklabels_list = [];

    for i = 1:length(neurons_in_batch)
        cellIndex = neurons_in_batch(i);

        % Masquer les neurones sélectionnés si demandé
        if ~show_traces && ismember(cellIndex, selected_total)
            continue;
        end

        trace = DF(cellIndex, :);

        % Déterminer style
        if ismember(cellIndex, blue_indices)
            if ismember(cellIndex, selected_total)
                color = [1, 0, 0]; % rouge
                lineWidth = 1.5;
            else
                color = [0, 1, 1]; % cyan normal
                lineWidth = 0.5;
            end
            tag = 'cellpose';
        else
            if ismember(cellIndex, selected_total)
                color = [1, 0, 0]; % rouge
                lineWidth = 1.5;
            else
                color = [0, 0, 0]; % noir normal
                lineWidth = 0.5;
            end
            tag = 'gcamp';
        end

        % Tracé
        h = plot(ax2, trace + vertical_offset, 'Color', color, 'LineWidth', lineWidth);
        set(h, 'HitTest', 'on', 'PickableParts', 'all');
        set(h, 'ButtonDownFcn', @(src, event) neuron_clicked(src, event, cellIndex, main_fig_handle, tag));

        yticks_pos(end+1) = vertical_offset + max(trace)/2;
        yticklabels_list{end+1} = num2str(cellIndex);
        vertical_offset = vertical_offset + max(trace)*1.2;
    end

    xlabel(ax2, 'Frame');
    title(ax2, 'Sorted Cell Traces (selection updated)');
    xlim(ax2, [0 num_columns]);
    ax2.YTick = yticks_pos;
    ax2.YTickLabel = yticklabels_list;
    axis(ax2, 'tight');
    grid(ax2, 'on');
    hold(ax2, 'off');
end



%%
% --- Toggle traces ---
function toggle_traces_display(fig_handle, btn)
    if ~isappdata(fig_handle, 'show_selected_traces')
        setappdata(fig_handle, 'show_selected_traces', true);
    end
    show_traces = getappdata(fig_handle, 'show_selected_traces');

    if show_traces
        setappdata(fig_handle, 'show_selected_traces', false);
        btn.String = 'Montrer traces';
    else
        setappdata(fig_handle, 'show_selected_traces', true);
        btn.String = 'Masquer traces';
    end

    % Mettre à jour les 2 affichages
    update_traces_subplot(fig_handle);
    update_gcamp_figure(fig_handle);
end


% --- Clic cellule ---
function neuron_clicked(~, ~, idx, fig_handle, source)
    click_type = get(gcbf, 'SelectionType');

    if isappdata(fig_handle, 'selected_neurons_total')
        selected_neurons_total = getappdata(fig_handle, 'selected_neurons_total');
    else
        selected_neurons_total = [];
    end

    if strcmp(click_type, 'normal') % clic gauche
        if ~ismember(idx, selected_neurons_total)
            selected_neurons_total(end+1) = idx;
        end
    elseif strcmp(click_type, 'alt') % clic droit
        selected_neurons_total(selected_neurons_total == idx) = [];
    end

    setappdata(fig_handle, 'selected_neurons_total', selected_neurons_total);

    update_gcamp_figure(fig_handle);
    update_traces_subplot(fig_handle);
end


function validate_selection(fig, index, current_gcamp_folder)
    if ~isvalid(fig), return; end

    % Récupérer la sélection courante depuis la figure
    if isappdata(fig, 'selected_neurons_total')
        selected_neurons = getappdata(fig, 'selected_neurons_total');
    else
        selected_neurons = [];
    end

    % Sauvegarder temporairement dans le root pour récupération après uiwait
    setappdata(0, sprintf('selected_result_%d', index), selected_neurons);

    % Ask the user if they want to launch Suite2p
    answer = questdlg('Voulez-vous démarrer Suite2p pour processer cet enregistrement?', ...
                      'Suite2p', 'Oui', 'Non', 'Non');

    % Sauvegarder la réponse
    if strcmp(answer, 'Oui')
        setappdata(0, sprintf('selection_saved_%d', index), true);
        show_recap_figure(fig, selected_neurons, index, current_gcamp_folder);
        suite2p = true;
    elseif strcmp(answer, 'Non')
        setappdata(0, sprintf('selection_saved_%d', index), false);
    else
        setappdata(0, sprintf('selection_saved_%d', index), false);
    end
    
    % Fermer les figures et reprendre l'exécution
    try
        uiresume(fig);  % libère uiwait dans la fonction principale
    catch
    end

    if isappdata(fig, 'parent_figure')
        parent_fig = getappdata(fig, 'parent_figure');
        if ~isempty(parent_fig) && isvalid(parent_fig)
            set(parent_fig, 'DeleteFcn', '');
            delete(parent_fig);
        end
    end
    set(fig, 'DeleteFcn', '');
    delete(fig);
end


% --- Affichage récapitulatif ---
function show_recap_figure(fig, selected_neurons, index, current_gcamp_folder)
    if ~isvalid(fig), return; end
    meanImg = getappdata(fig, 'meanImg');
    checking_choice2 = getappdata(fig, 'checking_choice2');
    outline_gcampx = getappdata(fig, 'outline_gcampx');
    outline_gcampy = getappdata(fig, 'outline_gcampy');
    outline_cellposex = getappdata(fig, 'outline_cellposex');
    outline_cellposey = getappdata(fig, 'outline_cellposey');
    blue_indices = getappdata(fig, 'blue_indices');

    recap_fig = figure('Name', 'Résumé sélection – GCaMP');
    screen_size = get(0, 'ScreenSize');
    set(recap_fig, 'Position', [1, 1, screen_size(3)/2, screen_size(4)]);
    hold on;
    imagesc(meanImg); colormap gray; axis image; set(gca,'YDir','reverse'); title('Sélection finale (rouge)');

    map_cellpose_idx = containers.Map('KeyType','double','ValueType','double');
    for k0 = 1:length(blue_indices)
        map_cellpose_idx(blue_indices(k0)) = k0;
    end
    for n = 1:length(blue_indices)
        idx = blue_indices(n);
        if map_cellpose_idx.isKey(idx)
            k = map_cellpose_idx(idx);
            if k <= length(outline_cellposex)
                color = 'b'; ms = 1;
                if ismember(idx, selected_neurons), color = 'r'; ms = 7; end
                plot(outline_cellposex{k}, outline_cellposey{k}, '.', 'MarkerSize', ms, 'Color', color);
            end
        end
    end

    rng(42);
    for idx = 1:length(outline_gcampx)
        color = rand(1,3); ms = 1;
        if ismember(idx, selected_neurons), color = 'r'; ms = 7; end
        plot(outline_gcampx{idx}, outline_gcampy{idx}, '.', 'MarkerSize', ms, 'Color', color);
    end
    hold off;

    launch_suite2p_from_matlab(current_gcamp_folder);
end

function launch_suite2p_from_matlab(image_path)
    % This function configures the Python environment for Suite2p and launches Suite2p from MATLAB with the graphical interface.
    %
    % Arguments:
    %   - image_path: The path to the image to be processed (in .tif or .png format).
    % Example:
    %   launch_suite2p_from_matlab('C:\path\to\image.png');

    % Path to the Python executable in the Suite2p Conda environment
    pyExec = 'C:\Users\goldstein\AppData\Local\anaconda3\envs\suite2p\python.exe';  % Update with your own path

    % Check if the Python environment is already configured
    currentPyEnv = pyenv;  % Do not pass arguments to pyenv
    
    if ~strcmp(currentPyEnv.Version, pyExec)
        % If the Python environment is not the one we want, configure it
        pyenv('Version', pyExec);  % Configure the Python environment
    end

    % Check if the Python environment is properly configured
    try
        py.print("Python is working with Suite2p!");
    catch
        error('Error: Python is not properly configured in MATLAB.');
    end

    % Add Suite2p path to the PATH if necessary
    setenv('PATH', [getenv('PATH') ';C:\Users\goldstein\AppData\Local\anaconda3\envs\suite2p\Scripts']);
    
    % Launch the Suite2p graphical interface
    fprintf('Launching Suite2p with the graphical interface to process the folder: %s\n', image_path);
    suite2pPath = 'C:\Users\goldstein\AppData\Local\anaconda3\envs\suite2p\Scripts\suite2p.exe';  % Specify the absolute path
    system(suite2pPath);  % Launch Suite2p with the graphical interface
   
end

function [min_val, max_val] = calculate_scaling(data)
    flattened_data = data(:);
    min_val = prctile(flattened_data, 5);
    max_val = prctile(flattened_data, 99.9);
    if min_val >= max_val
        warning('Invalid color scale limits, using raw min/max.');
        min_val = min(flattened_data);
        max_val = max(flattened_data);
    end
end

function inspect_traces_callback(gcamp_fig, data, idx, current_animal_group, current_ages_group)
    % --- 1. Récupérer les neurones sélectionnés dans le batch courant ---
    selected_neurons_total = getappdata(gcamp_fig, 'selected_neurons_total');
    neurons_in_batch = getappdata(gcamp_fig, 'neurons_in_batch');

    % Filtrer uniquement ceux du batch courant
    selected_neurons_ordered = intersect(selected_neurons_total, neurons_in_batch, 'stable');

    if isempty(selected_neurons_ordered)
        warndlg('Aucun neurone sélectionné dans ce batch.', 'Attention');
        return;
    end

    % --- 2. Récupérer DF et indices valides ---
    DF = data.DF_gcamp{idx};
    F = data.F_gcamp{idx};
    valid_neurons = any(~isnan(DF), 2);
    valid_neuron_indices = find(valid_neurons);

    % Indices originaux
    selected_gcamp_neurons_original = valid_neuron_indices(selected_neurons_ordered);

    % --- 3. Préparer figure unique ---
    fig = figure('Name', sprintf('Inspection – %s (%s)', current_animal_group, current_ages_group{idx}));
    screen_size = get(0, 'ScreenSize');
    set(fig, 'Position', [50, 50, screen_size(3)*0.8, screen_size(4)*0.8]);

    tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

    % --- 4. Tracer F ---
    ax1 = nexttile;
    hold(ax1, 'on');
    offset = 0;
    for k = 1:length(selected_gcamp_neurons_original)
        cellIdx = selected_gcamp_neurons_original(k);
        trace = F(cellIdx, :);
        plot(ax1, trace + offset, 'LineWidth', 1);
        text(size(F,2)+20, offset, sprintf('Cell %d', cellIdx), 'Parent', ax1);
        offset = offset + max(trace)*1.2;
    end
    hold(ax1, 'off');
    xlabel(ax1, 'Frame');
    ylabel(ax1, 'F (a.u.)');
    title(ax1, 'Traces F des neurones sélectionnés');
    grid(ax1, 'on');

    % --- 5. Tracer ΔF/F ---
    ax2 = nexttile;
    hold(ax2, 'on');
    offset = 0;
    for k = 1:length(selected_gcamp_neurons_original)
        cellIdx = selected_gcamp_neurons_original(k);
        trace = DF(cellIdx, :);
        plot(ax2, trace + offset, 'LineWidth', 1);
        text(size(DF,2)+20, offset, sprintf('Cell %d', cellIdx), 'Parent', ax2);
        offset = offset + max(trace)*1.5;
    end
    hold(ax2, 'off');
    xlabel(ax2, 'Frame');
    ylabel(ax2, '\DeltaF/F');
    title(ax2, 'Traces ΔF/F des neurones sélectionnés');
    grid(ax2, 'on');
end