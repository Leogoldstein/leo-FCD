function selected_neurons_all = data_checking(data, gcamp_output_folders, current_gcamp_folders_group, current_animal_group, current_ages_group, meanImgs)
    % Initialisation du tableau de résultats (sélections par dossier)
    selected_neurons_all = cell(size(gcamp_output_folders));  % Pour stocker les sélections

    for m = 1:length(gcamp_output_folders)
        try
            if ~isempty(data.F_combined{m})
                F = data.F_combined{m};
                DF = data.DF_combined{m};
                isort1 = data.isort1_combined{m};
                MAct = data.MAct_combined{m}; 
                blue_indices = data.blue_indices{m};
            else
                F = data.F_gcamp{m};
                DF = data.DF_gcamp{m};
                isort1 = data.isort1_gcamp{m};
                MAct = data.MAct_gcamp{m};
                blue_indices = [];
            end

            valid_neurons = all(~isnan(DF), 2);
            F = F(valid_neurons, :);
            %assignin('base', 'F', F);

            DF = DF(valid_neurons, :);

            valid_neuron_indices = find(valid_neurons);
            isort1 = isort1(ismember(isort1, valid_neuron_indices));
            [~, isort1] = ismember(isort1, valid_neuron_indices);
    
            batch_size = 50;
            total_neurons = length(isort1);
            num_batches = ceil(total_neurons / batch_size);
            num_columns = size(F, 2);

            % Figure principale
            main_fig = figure;
            screen_size = get(0, 'ScreenSize');
            set(main_fig, 'Position', screen_size);
            figure(main_fig); % <-- rendre active main_fig avant subplot
    
            % Subplots (ax1, ax2, ax3)
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
            try
                xlim(ax3, [1 num_columns]);
            catch
                warning('xlim skipped: num_columns invalid (%d)', num_columns);
            end

            grid(ax3, 'on');
                
            % Initialisation variable sélectionnée
            selected_neurons = [];
            
            % Crée le slider (sans callback pour l’instant)
            slider_handle = uicontrol('Style', 'slider', ...
                'Min', 1, 'Max', num_batches, 'Value', 1, ...
                'SliderStep', [1/(max(num_batches-1,1)), 1/(max(num_batches-1,1))], ...
                'Units', 'normalized', ...
                'Position', [0.1 0.21 0.85 0.02]);
            
            % Définis maintenant la callback en utilisant le slider_handle défini
            slider_handle.Callback = @(src, ~) update_batch_display(slider_handle, F, DF, isort1, batch_size, num_columns, ...
                ax1, ax1_right, ax2, meanImgs, MAct, blue_indices, NCell, m, data);

                    
            linkaxes([ax1, ax2, ax3], 'x');
            sgtitle(sprintf('%s – %s', current_animal_group, current_ages_group{m}), 'FontWeight', 'bold');
    
            % GCaMP figure
            gcamp_fig = findobj('Type', 'figure', 'Name', 'GCaMP Figure');
            if isempty(gcamp_fig)
                gcamp_fig = figure('Name', 'GCaMP Figure', ...
                                   'CloseRequestFcn', @(src, ~) gcamp_close_callback(src, m, current_gcamp_folders_group{m}));
            else
                set(gcamp_fig, 'CloseRequestFcn', @(src, ~) gcamp_close_callback(src, m, current_gcamp_folders_group{m}));
            end
    
            % Set data in GCaMP figure
            setappdata(gcamp_fig, 'meanImg', meanImgs{m});
            setappdata(gcamp_fig, 'outline_gcampx', data.outlines_gcampx{m});
            setappdata(gcamp_fig, 'outline_gcampy', data.outlines_gcampy{m});
            setappdata(gcamp_fig, 'outline_cellposex', data.outlines_x_cellpose{m});
            setappdata(gcamp_fig, 'outline_cellposey', data.outlines_y_cellpose{m});
            setappdata(gcamp_fig, 'selected_neurons', []);
            setappdata(gcamp_fig, 'neurons_in_batch', []);
            setappdata(gcamp_fig, 'output_index', m);
            setappdata(gcamp_fig, 'parent_figure', main_fig);
    
            % Initial display
            update_batch_display(slider_handle, F, DF, isort1, batch_size, num_columns, ax1, ax1_right, ax2, meanImgs, MAct, blue_indices, NCell, m, data);

            % Attendre que la figure GCaMP soit fermée manuellement
            waitfor(gcamp_fig);
    
            % Récupérer les résultats si validés
            if isappdata(0, sprintf('selection_saved_%d', m)) && getappdata(0, sprintf('selection_saved_%d', m))
                selected_neurons_all{m} = getappdata(0, sprintf('selected_result_%d', m));
            else
                selected_neurons_all{m} = [];
            end
    
            % Fermer aussi la figure principale si elle est encore ouverte
            if isvalid(main_fig)
                close(main_fig);
            end
    
        catch ME
            fprintf('\nErreur à l''étape %d : %s\n', m, ME.message);
            selected_neurons_all{m} = [];
        end

        waitfor(gcamp_fig);
    end
end

function gcamp_close_callback(fig, index, current_gcamp_folder)
    % Récupérer la sélection cumulée correcte
    if isappdata(fig, 'selected_neurons_total')
        selected_neurons = getappdata(fig, 'selected_neurons_total');
    else
        selected_neurons = [];
    end
    
    answer = questdlg('Voulez-vous enregistrer cette sélection ?', ...
                      'Confirmation', 'Oui', 'Non', 'Annuler', 'Oui');
    switch answer
        case 'Oui'
            % Enregistre sélection dans appdata root pour l’étape suivante
            setappdata(0, sprintf('selection_saved_%d', index), true);
            setappdata(0, sprintf('selected_result_%d', index), selected_neurons);

            % --- Nouvelle figure récap avec toutes les cellules ---
            meanImg = getappdata(fig, 'meanImg');
            outline_gcampx = getappdata(fig, 'outline_gcampx');
            outline_gcampy = getappdata(fig, 'outline_gcampy');
            outline_cellposex = getappdata(fig, 'outline_cellposex');
            outline_cellposey = getappdata(fig, 'outline_cellposey');
            blue_indices = getappdata(fig, 'blue_indices');

            recap_fig = figure('Name', 'Résumé sélection – GCaMP');

            % Affichage en demi-écran gauche
            screen_size = get(0, 'ScreenSize');  % [x y width height]
            set(recap_fig, 'Position', [1, 1, screen_size(3)/2, screen_size(4)]);

            hold on;
            imagesc(meanImg);
            colormap gray;
            axis image;
            set(gca, 'YDir', 'reverse');
            title('Sélection finale (rouge)');

            % --- Affichage Cellpose ---
            map_cellpose_idx = containers.Map('KeyType', 'double', 'ValueType', 'double');
            for k0 = 1:length(blue_indices)
                map_cellpose_idx(blue_indices(k0)) = k0;
            end
            for n = 1:length(blue_indices)
                idx = blue_indices(n);
                if map_cellpose_idx.isKey(idx)
                    k = map_cellpose_idx(idx);
                    if k <= length(outline_cellposex)
                        if ismember(idx, selected_neurons)
                            color = 'r'; ms = 7;   % sélectionné = rouge
                        else
                            color = 'b'; ms = 1;   % sinon bleu
                        end
                        plot(outline_cellposex{k}, outline_cellposey{k}, '.', ...
                             'MarkerSize', ms, 'Color', color);
                    end
                end
            end

            % --- Affichage GCaMP ---
            rng(42); % reproductibilité des couleurs aléatoires
            for idx = 1:length(outline_gcampx)
                if ismember(idx, selected_neurons)
                    color = 'r'; ms = 7; % sélectionné en rouge
                else
                    color = rand(1,3); ms = 1; % couleur aléatoire
                end
                plot(outline_gcampx{idx}, outline_gcampy{idx}, '.', ...
                     'MarkerSize', ms, 'Color', color);
            end
            hold off;

            % open suite2p
            launch_suite2p_from_matlab(current_gcamp_folder)

            delete(fig)
            
        case 'Non'
            setappdata(0, sprintf('selection_saved_%d', index), false);
            delete(fig)
            
        case 'Annuler'
            % Ne pas fermer : juste sortir de la callback
            return;
    end
end


function update_batch_display(slider_handle, F, DF, isort1, batch_size, num_columns, ax1, ax1_right, ax2, meanImgs, MAct, blue_indices, NCell, m, data)

    % Trouver figure GCaMP ou en créer une nouvelle
    figure_handle = findobj('Type', 'figure', 'Name', 'GCaMP Figure');
    if isempty(figure_handle)
        figure_handle = figure('Name', 'GCaMP Figure');
        setappdata(figure_handle, 'meanImg', meanImgs{m});
        setappdata(figure_handle, 'outline_gcampx', data.outlines_gcampx{m});
        setappdata(figure_handle, 'outline_gcampy', data.outlines_gcampy{m});
        setappdata(figure_handle, 'outline_cellposex', data.outlines_x_cellpose{m});
        setappdata(figure_handle, 'outline_cellposey', data.outlines_y_cellpose{m});
        setappdata(figure_handle, 'blue_indices', blue_indices);
        % Initialiser appdata de sélections
        setappdata(figure_handle, 'selected_neurons_total', []);
        setappdata(figure_handle, 'selected_neurons_gcamp', []);
        setappdata(figure_handle, 'selected_neurons_cellpose', []);
    else
        figure(figure_handle);
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
    setappdata(figure_handle, 'meanImgs', meanImgs);
    setappdata(figure_handle, 'outlines_gcampx', data.outlines_gcampx{m});
    setappdata(figure_handle, 'outlines_gcampy', data.outlines_gcampy{m});
    setappdata(figure_handle, 'MAct', MAct);
    setappdata(figure_handle, 'NCell', NCell);
    setappdata(figure_handle, 'm', m);
    setappdata(figure_handle, 'outlines_x_cellpose', data.outlines_x_cellpose{m});
    setappdata(figure_handle, 'outlines_y_cellpose', data.outlines_y_cellpose{m});
    setappdata(figure_handle, 'blue_indices', blue_indices);

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
    cla(ax1_right);
    ax1_right.YLim = ax1.YLim;
    ax1_right.XLim = ax1.XLim;
    ax1_right.YTick = start_idx:end_idx;
    ax1_right.YTickLabel = arrayfun(@num2str, neurons_in_batch, 'UniformOutput', false);
    ax1_right.XTick = [];
    ax1_right.YDir = 'normal';
    ylabel(ax1_right, 'Batch Neuron IDs');
end


function validate_selection_callback(~, ~)
    fig_handle = gcbf;  % figure courante

    % --- Récupération des sélections actuelles ---
    selected_gcamp = [];
    selected_cellpose = [];

    if isappdata(fig_handle, 'selected_neurons_gcamp')
        selected_gcamp = getappdata(fig_handle, 'selected_neurons_gcamp');
    end
    if isappdata(fig_handle, 'selected_neurons_cellpose')
        selected_cellpose = getappdata(fig_handle, 'selected_neurons_cellpose');
    end

    selected_neurons_batch = union(selected_gcamp, selected_cellpose);

    % --- Récupération sélection cumulée ---
    if isappdata(fig_handle, 'selected_neurons_total')
        selected_neurons_total = getappdata(fig_handle, 'selected_neurons_total');
    else
        selected_neurons_total = [];
    end

    % --- Mise à jour sélection totale ---
    selected_neurons_total = union(selected_neurons_total, selected_neurons_batch);
    setappdata(fig_handle, 'selected_neurons_total', selected_neurons_total);

    % Nettoyage des sélections du batch courant
    setappdata(fig_handle, 'selected_neurons_gcamp', []);
    setappdata(fig_handle, 'selected_neurons_cellpose', []);

    % Remettre à jour les traces avec les neurones restants
    update_traces_subplot(fig_handle);
end




function update_gcamp_figure(fig_handle)
    % --- 1. Récupération des données ---
    meanImg = getappdata(fig_handle, 'meanImg');
    outline_gcampx = getappdata(fig_handle, 'outline_gcampx');
    outline_gcampy = getappdata(fig_handle, 'outline_gcampy');
    outline_cellposex = getappdata(fig_handle, 'outline_cellposex');
    outline_cellposey = getappdata(fig_handle, 'outline_cellposey');
    neurons_in_batch = getappdata(fig_handle, 'neurons_in_batch');
    selected_gcamp = getappdata(fig_handle, 'selected_neurons_gcamp');
    selected_cellpose = getappdata(fig_handle, 'selected_neurons_cellpose');
    blue_indices = getappdata(fig_handle, 'blue_indices');

    if isempty(selected_gcamp), selected_gcamp = []; end
    if isempty(selected_cellpose), selected_cellpose = []; end

    % --- 2. Axe dédié ---
    if ~isappdata(fig_handle, 'ax_gcamp')
        ax_gcamp = axes('Parent', fig_handle);
        setappdata(fig_handle, 'ax_gcamp', ax_gcamp);
    else
        ax_gcamp = getappdata(fig_handle, 'ax_gcamp');
    end

    cla(ax_gcamp);  % on efface uniquement cet axe
    hold(ax_gcamp, 'on');
    imagesc(ax_gcamp, meanImg);
    colormap(ax_gcamp, gray);
    axis(ax_gcamp, 'image');
    set(ax_gcamp, 'YDir', 'reverse');
    title(ax_gcamp, 'GCaMP outlines');

    % --- 3. Couleurs stables pour GCaMP ---
    if ~isappdata(fig_handle, 'gcamp_colors')
        rng(42); % pour reproductibilité
        gcamp_colors = rand(length(outline_gcampx), 3);
        setappdata(fig_handle, 'gcamp_colors', gcamp_colors);
    else
        gcamp_colors = getappdata(fig_handle, 'gcamp_colors');
    end

    % --- 4. Map Cellpose indices ---
    map_cellpose_idx = containers.Map('KeyType', 'double', 'ValueType', 'double');
    for k0 = 1:length(blue_indices)
        map_cellpose_idx(blue_indices(k0)) = k0;
    end

    % --- 5. Tracer les neurones du batch ---
    for n = 1:length(neurons_in_batch)
        idx = neurons_in_batch(n);

        % Cellpose neurons
        if ismember(idx, blue_indices) && map_cellpose_idx.isKey(idx)
            k = map_cellpose_idx(idx);
            if k <= length(outline_cellposex)
                if ismember(idx, selected_cellpose)
                    color = 'r'; ms = 7;
                else
                    color = 'b'; ms = 1;
                end
                h = plot(ax_gcamp, outline_cellposex{k}, outline_cellposey{k}, '.', ...
                         'MarkerSize', ms, 'Color', color);
                set(h, 'ButtonDownFcn', @(src, event) neuron_clicked(src, event, idx, fig_handle, 'cellpose'));
                set(h, 'HitTest', 'on', 'PickableParts', 'all');
            end

        % GCaMP neurons
        elseif idx <= length(outline_gcampx)
            if ismember(idx, selected_gcamp)
                color = 'r'; ms = 7;
            else
                color = gcamp_colors(idx, :); ms = 1;
            end
            h = plot(ax_gcamp, outline_gcampx{idx}, outline_gcampy{idx}, '.', ...
                     'MarkerSize', ms, 'Color', color);
            set(h, 'ButtonDownFcn', @(src, event) neuron_clicked(src, event, idx, fig_handle, 'gcamp'));
            set(h, 'HitTest', 'on', 'PickableParts', 'all');
        end
    end

    hold(ax_gcamp, 'off');

    % --- 6. Bouton de validation ---
    existing_btn = findobj(fig_handle, 'Type', 'uicontrol', 'String', 'Valider la sélection');
    if isempty(existing_btn)
        uicontrol('Parent', fig_handle, 'Style', 'pushbutton', ...
            'String', 'Valider la sélection', 'Units', 'normalized', ...
            'Position', [0.85, 0.01, 0.13, 0.05], ...
            'Callback', @validate_selection_callback);
    end
end



function neuron_clicked(~, ~, idx, fig_handle, source)
    click_type = get(gcbf, 'SelectionType');

    % Charger la liste appropriée
    if strcmp(source, 'gcamp')
        selected = getappdata(fig_handle, 'selected_neurons_gcamp');
        if isempty(selected), selected = []; end
    else
        selected = getappdata(fig_handle, 'selected_neurons_cellpose');
        if isempty(selected), selected = []; end
    end

    % Gérer la sélection/désélection
    if strcmp(click_type, 'normal')  % clic gauche
        if ~ismember(idx, selected)
            selected(end+1) = idx;
        end
    elseif strcmp(click_type, 'alt')  % clic droit
        selected(selected == idx) = [];
    end

    % Enregistrer la liste mise à jour
    if strcmp(source, 'gcamp')
        setappdata(fig_handle, 'selected_neurons_gcamp', selected);
    else
        setappdata(fig_handle, 'selected_neurons_cellpose', selected);
    end

    % Mise à jour de l'affichage
    update_gcamp_figure(fig_handle);
    update_traces_subplot(fig_handle);
end

function update_traces_subplot(main_fig_handle)
    ax2 = getappdata(main_fig_handle, 'ax2');
    F = getappdata(main_fig_handle, 'F');
    neurons_in_batch = getappdata(main_fig_handle, 'neurons_in_batch');
    blue_indices = getappdata(main_fig_handle, 'blue_indices');
    num_columns = getappdata(main_fig_handle, 'num_columns');

    selected_gcamp = getappdata(main_fig_handle, 'selected_neurons_gcamp');
    selected_cellpose = getappdata(main_fig_handle, 'selected_neurons_cellpose');
    selected_total = getappdata(main_fig_handle, 'selected_neurons_total');

    if isempty(selected_gcamp), selected_gcamp = []; end
    if isempty(selected_cellpose), selected_cellpose = []; end
    if isempty(selected_total), selected_total = []; end

    cla(ax2);
    hold(ax2, 'on');
    vertical_offset = 0;
    yticks_pos = [];
    yticklabels_list = [];

    for i = 1:length(neurons_in_batch)
        cellIndex = neurons_in_batch(i);

        % Ignorer les neurones déjà validés (sélection cumulée)
        if ismember(cellIndex, selected_total)
            continue;
        end

        trace = F(cellIndex, :);

        % Déterminer si c’est une cellule Cellpose (bleue)
        is_cellpose = ismember(cellIndex, blue_indices);
        is_selected_gcamp = ismember(cellIndex, selected_gcamp);
        is_selected_cellpose = ismember(cellIndex, selected_cellpose);

        % Couleur et épaisseur selon type et sélection temporaire
        if is_cellpose
            if is_selected_cellpose
                color = [1, 0, 0]; % rouge sélection temporaire
                lineWidth = 1.5;
            else
                color = [0, 1, 1]; % cyan normal
                lineWidth = 0.5;
            end
            tag = 'cellpose';
        else
            if is_selected_gcamp
                color = [1, 0, 0]; % rouge sélection temporaire
                lineWidth = 1.5;
            else
                color = [0, 0, 0]; % noir normal
                lineWidth = 0.5;
            end
            tag = 'gcamp';
        end

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
    
    % Ask the user if they want to launch Suite2p
    answer = questdlg('Veux-tu démarrer Suite2p pour processer cet enregistrement?', ...
        'Launch Suite2p', 'Yes', 'No', 'No');
    
    % If the user answers "Yes", launch suite2p
    if strcmp(answer, 'Yes')
        % Launch the Suite2p graphical interface
        fprintf('Launching Suite2p with the graphical interface to process the folder: %s\n', image_path);
        suite2pPath = 'C:\Users\goldstein\AppData\Local\anaconda3\envs\suite2p\Scripts\suite2p.exe';  % Specify the absolute path
        system(suite2pPath);  % Launch Suite2p with the graphical interface
    else
        fprintf('Suite2p was not launched. Process canceled.\n');
    end
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