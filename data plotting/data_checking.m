function selected_neurons_all = data_checking(all_DF, all_isort1, all_MAct, ...
    gcamp_output_folders, current_gcamp_folders_group, ...
    current_animal_group, current_ages_group, meanImgs, ...
    outline_gcampx_all, outline_gcampy_all, ...
    all_data_DF, all_data_MAct, all_data_isort1, ...
    outlines_x_cellpose, outlines_y_cellpose, blue_indices_all)

    % Initialisation du tableau de résultats (sélections par dossier)
    selected_neurons_all = cell(size(gcamp_output_folders));  % Pour stocker les sélections

    for m = 1:length(gcamp_output_folders)
        try
            if ~isempty(all_data_DF{m})
                DF = all_data_DF{m};
                isort1 = all_data_isort1{m};
                MAct = all_data_MAct{m}; 
                blue_indices = blue_indices_all{m};
            else
                DF = all_DF{m};
                isort1 = all_isort1{m};
                MAct = all_MAct{m};
                blue_indices = [];
            end
            
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
            main_fig = figure;
            screen_size = get(0, 'ScreenSize');
            set(main_fig, 'Position', screen_size);
    
            % Subplots (ax1, ax2, ax3)
            ax1 = subplot('Position', [0.1, 0.75, 0.85, 0.15]);
            ax1_right = axes('Position', ax1.Position, 'YAxisLocation', 'right', ...
                             'Color', 'none', 'XTick', [], 'Box', 'off');
            ax1_right.YDir = 'normal';
            ax1_right.XLim = ax1.XLim;
    
            ax2 = subplot('Position', [0.1, 0.25, 0.85, 0.45]);
            ax3 = subplot('Position', [0.1, 0.05, 0.85, 0.15]);
    
            MAct = all_MAct{m};
            NCell = size(DF, 1);
            % Initialisation variable sélectionnée
            selected_neurons = [];
            
            % Crée le slider (sans callback pour l’instant)
            slider_handle = uicontrol('Style', 'slider', ...
                'Min', 1, 'Max', num_batches, 'Value', 1, ...
                'SliderStep', [1/(max(num_batches-1,1)), 1/(max(num_batches-1,1))], ...
                'Units', 'normalized', ...
                'Position', [0.1 0.21 0.85 0.02]);
            
            % Définis maintenant la callback en utilisant le slider_handle défini
            slider_handle.Callback = @(src, ~) update_batch_display(slider_handle, DF, isort1, batch_size, num_columns, ...
                ax1, ax1_right, ax2, ax3, meanImgs, outline_gcampx_all, outline_gcampy_all, ...
                MAct, NCell, m, outlines_x_cellpose, outlines_y_cellpose, selected_neurons, blue_indices);

                    
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
            setappdata(gcamp_fig, 'outline_gcampx', outline_gcampx_all{m});
            setappdata(gcamp_fig, 'outline_gcampy', outline_gcampy_all{m});
            setappdata(gcamp_fig, 'outline_cellposex', outlines_x_cellpose{m});
            setappdata(gcamp_fig, 'outline_cellposey', outlines_y_cellpose{m});
            setappdata(gcamp_fig, 'selected_neurons', []);
            setappdata(gcamp_fig, 'neurons_in_batch', []);
            setappdata(gcamp_fig, 'output_index', m);
            setappdata(gcamp_fig, 'parent_figure', main_fig);
    
            % Initial display
            update_batch_display(slider_handle, DF, isort1, batch_size, num_columns, ...
            ax1, ax1_right, ax2, ax3, meanImgs, outline_gcampx_all, outline_gcampy_all, ...
            MAct, NCell, m, outlines_x_cellpose, outlines_y_cellpose, selected_neurons, blue_indices);

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
    end
end

function gcamp_close_callback(fig, index, current_gcamp_folder)
    selected_neurons = getappdata(fig, 'selected_neurons');
    answer = questdlg('Voulez-vous enregistrer cette sélection ?', ...
                      'Confirmation', 'Oui', 'Non', 'Annuler', 'Oui');
    switch answer
        case 'Oui'
            % Enregistre sélection dans appdata root pour l’étape suivante
            setappdata(0, sprintf('selection_saved_%d', index), true);
            setappdata(0, sprintf('selected_result_%d', index), selected_neurons);

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


function update_batch_display(slider_handle, DF, isort1, batch_size, num_columns, ax1, ax1_right, ax2, ax3, ...
    meanImgs, outline_gcampx_all, outline_gcampy_all, MAct, NCell, m, ...
    outlines_x_cellpose, outlines_y_cellpose, selected_neurons, blue_indices)

    if nargin < 19
        selected_neurons = [];
    end

    % Exclure les neurones sélectionnés de isort1
    if isempty(selected_neurons)
        isort1_filtered = isort1;
    else
        isort1_filtered = setdiff(isort1, selected_neurons);
    end

    batch_index = round(get(slider_handle, 'Value'));
    start_idx = (batch_index - 1) * batch_size + 1;
    end_idx = min(batch_index * batch_size, length(isort1_filtered));
    neurons_in_batch = isort1_filtered(start_idx:end_idx);

    % --- Mise à jour appdata GCaMP Figure (création ou récupération) ---
    figure_handle = findobj('Type', 'figure', 'Name', 'GCaMP Figure');
    if isempty(figure_handle)
        figure_handle = figure('Name', 'GCaMP Figure');
        setappdata(figure_handle, 'meanImg', meanImgs{m});
        setappdata(figure_handle, 'outline_gcampx', outline_gcampx_all{m});
        setappdata(figure_handle, 'outline_gcampy', outline_gcampy_all{m});
        setappdata(figure_handle, 'selected_neurons_gcamp', []);
        setappdata(figure_handle, 'selected_neurons_cellpose', []);
        setappdata(figure_handle, 'outline_cellposex', outlines_x_cellpose{m});
        setappdata(figure_handle, 'outline_cellposey', outlines_y_cellpose{m});
    else
        figure(figure_handle);
    end

    % Stocke batch courant pour affichage verts
    setappdata(figure_handle, 'neurons_in_batch', neurons_in_batch);
    setappdata(figure_handle, 'slider_handle', slider_handle);
    setappdata(figure_handle, 'DF', DF);
    setappdata(figure_handle, 'isort1', isort1);
    setappdata(figure_handle, 'batch_size', batch_size);
    setappdata(figure_handle, 'num_columns', num_columns);
    setappdata(figure_handle, 'ax1', ax1);
    setappdata(figure_handle, 'ax1_right', ax1_right);
    setappdata(figure_handle, 'ax2', ax2);
    setappdata(figure_handle, 'ax3', ax3);
    setappdata(figure_handle, 'meanImgs', meanImgs);
    setappdata(figure_handle, 'outline_gcampx_all', outline_gcampx_all);
    setappdata(figure_handle, 'outline_gcampy_all', outline_gcampy_all);
    setappdata(figure_handle, 'MAct', MAct);
    setappdata(figure_handle, 'NCell', NCell);
    setappdata(figure_handle, 'm', m);
    setappdata(figure_handle, 'outlines_x_cellpose', outlines_x_cellpose);
    setappdata(figure_handle, 'outlines_y_cellpose', outlines_y_cellpose);
    setappdata(figure_handle, 'selected_neurons_total', selected_neurons);
    setappdata(figure_handle, 'blue_indices', blue_indices);

    % --- Mise à jour figure GCaMP ---
    update_gcamp_figure(figure_handle);

    % --- Traces ax2 ---
    update_traces_subplot(figure_handle);

    % --- Raster et axe droit ---
    cla(ax1);
    imagesc(ax1, DF(isort1_filtered, :));
    [minValue, maxValue] = calculate_scaling(DF);
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

    % Axe droit
    cla(ax1_right);
    ax1_right.YLim = ax1.YLim;
    ax1_right.XLim = ax1.XLim;
    ax1_right.YTick = start_idx:end_idx;
    ax1_right.YTickLabel = arrayfun(@num2str, neurons_in_batch, 'UniformOutput', false);
    ax1_right.XTick = [];
    ax1_right.YDir = 'normal';
    ylabel(ax1_right, 'Batch Neuron IDs');

    % Subplot activité
    cla(ax3);
    prop_MAct = MAct / NCell;
    plot(ax3, prop_MAct, 'LineWidth', 2);
    xlabel(ax3, 'Frame');
    ylabel(ax3, 'Proportion of Active Cells');
    title(ax3, 'Activity Over Consecutive Frames');
    xlim(ax3, [0 num_columns]);
    grid(ax3, 'on');
end


function validate_selection_callback(~, ~)
    fig_handle = gcbf;  % figure courante

    % Récupération sécurisée des appdata
    if isappdata(fig_handle, 'selected_neurons_gcamp')
        selected_gcamp = getappdata(fig_handle, 'selected_neurons_gcamp');
    else
        selected_gcamp = [];
    end

    if isappdata(fig_handle, 'selected_neurons_cellpose')
        selected_cellpose = getappdata(fig_handle, 'selected_neurons_cellpose');
    else
        selected_cellpose = [];
    end

    % Fusion des sélections (union des indices)
    selected_neurons = union(selected_gcamp, selected_cellpose);

    % Récupération des autres données nécessaires
    slider_handle = getappdata(fig_handle, 'slider_handle');
    DF = getappdata(fig_handle, 'DF');
    isort1 = getappdata(fig_handle, 'isort1');
    batch_size = getappdata(fig_handle, 'batch_size');
    num_columns = getappdata(fig_handle, 'num_columns');
    ax1 = getappdata(fig_handle, 'ax1');
    ax1_right = getappdata(fig_handle, 'ax1_right');
    ax2 = getappdata(fig_handle, 'ax2');
    ax3 = getappdata(fig_handle, 'ax3');
    meanImgs = getappdata(fig_handle, 'meanImgs');
    outline_gcampx_all = getappdata(fig_handle, 'outline_gcampx_all');
    outline_gcampy_all = getappdata(fig_handle, 'outline_gcampy_all');
    MAct = getappdata(fig_handle, 'MAct');
    NCell = getappdata(fig_handle, 'NCell');
    m = getappdata(fig_handle, 'm');
    outlines_x_cellpose = getappdata(fig_handle, 'outlines_x_cellpose');
    outlines_y_cellpose = getappdata(fig_handle, 'outlines_y_cellpose');
    blue_indices = getappdata(fig_handle, 'blue_indices');

    % Mise à jour de l'affichage en excluant les neurones sélectionnés
    update_batch_display(slider_handle, DF, isort1, batch_size, num_columns, ...
    ax1, ax1_right, ax2, ax3, meanImgs, outline_gcampx_all, outline_gcampy_all, ...
    MAct, NCell, m, outlines_x_cellpose, outlines_y_cellpose, selected_neurons, blue_indices);


end




function update_gcamp_figure(fig_handle)
    % Récupération des données stockées dans appdata
    meanImg = getappdata(fig_handle, 'meanImg');
    outline_gcampx = getappdata(fig_handle, 'outline_gcampx');
    outline_gcampy = getappdata(fig_handle, 'outline_gcampy');
    outline_cellposex = getappdata(fig_handle, 'outline_cellposex');
    outline_cellposey = getappdata(fig_handle, 'outline_cellposey');
    neurons_in_batch = getappdata(fig_handle, 'neurons_in_batch');
    selected_gcamp = getappdata(fig_handle, 'selected_neurons_gcamp');
    selected_cellpose = getappdata(fig_handle, 'selected_neurons_cellpose');
    blue_indices = getappdata(fig_handle, 'blue_indices');

    % Si variables vides, initialiser pour éviter erreurs
    if isempty(selected_gcamp), selected_gcamp = []; end
    if isempty(selected_cellpose), selected_cellpose = []; end

    % Nettoyage et affichage
    figure(fig_handle);
    clf;
    hold on;
    imagesc(meanImg);
    colormap(gca, gray);
    axis image;
    set(gca, 'YDir', 'reverse');
    title('GCaMP outlines');

    k = 0; % compteur pour les outlines à tracer

    for n = 1:length(neurons_in_batch)
        idx = neurons_in_batch(n);
    
        % Vérifie si idx est valide et dans blue_indices
        if ismember(idx, blue_indices)
            k = k + 1; % on avance le compteur uniquement pour ceux qu'on affiche
    
            color = 'b'; markerSize = 1;
            if ismember(idx, selected_cellpose)
                color = 'r'; markerSize = 7;
            end
            
            % Utilise k pour accéder aux outlines
            h = plot(outline_cellposex{k}, outline_cellposey{k}, '.', ...
                'MarkerSize', markerSize, 'Color', color);
            set(h, 'ButtonDownFcn', @(src, event) neuron_clicked(src, event, idx, fig_handle, 'cellpose'));
            set(h, 'HitTest', 'on', 'PickableParts', 'all');
        
        elseif idx <= length(outline_gcampx) && idx <= length(outline_gcampy)
            color = 'g'; markerSize = 1;
            if ismember(idx, selected_gcamp)
                color = 'r'; markerSize = 7;
            end
            h = plot(outline_gcampx{idx}, outline_gcampy{idx}, '.', ...
                'MarkerSize', markerSize, 'Color', color);
            set(h, 'ButtonDownFcn', @(src, event) neuron_clicked(src, event, idx, fig_handle, 'gcamp'));
            set(h, 'HitTest', 'on', 'PickableParts', 'all');
        end
    end

    hold off;

    % Ajout du bouton de validation (uniquement s'il n'existe pas déjà)
    existing_btn = findobj(fig_handle, 'Type', 'uicontrol', 'String', 'Valider la sélection');
    if isempty(existing_btn)
        uicontrol('Parent', fig_handle, 'Style', 'pushbutton', ...
            'String', 'Valider la sélection', 'Units', 'normalized', ...
            'Position', [0.85, 0.01, 0.13, 0.05], 'Callback', @validate_selection_callback);
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
    DF = getappdata(main_fig_handle, 'DF');
    neurons_in_batch = getappdata(main_fig_handle, 'neurons_in_batch');
    blue_indices = getappdata(main_fig_handle, 'blue_indices');
    num_columns = getappdata(main_fig_handle, 'num_columns');
    selected_gcamp = getappdata(main_fig_handle, 'selected_neurons_gcamp');
    selected_cellpose = getappdata(main_fig_handle, 'selected_neurons_cellpose');

    if isempty(selected_gcamp), selected_gcamp = []; end
    if isempty(selected_cellpose), selected_cellpose = []; end

    cla(ax2);
    hold(ax2, 'on');
    vertical_offset = 0;
    yticks_pos = [];
    yticklabels_list = [];

    for i = 1:length(neurons_in_batch)
        cellIndex = neurons_in_batch(i);
        trace = DF(cellIndex, :);

        % Déterminer si c’est une cellule Cellpose (bleue)
        is_cellpose = ismember(cellIndex, blue_indices);
        is_selected_gcamp = ismember(cellIndex, selected_gcamp);
        is_selected_cellpose = ismember(cellIndex, selected_cellpose);

        % Définir couleur et épaisseur en fonction du type et de la sélection
        if is_cellpose
            if is_selected_cellpose
                color = [1, 0, 0]; % rouge
                lineWidth = 1.5;
            else
                color = [0, 1, 1]; % cyan
                lineWidth = 0.5;
            end
            tag = 'cellpose';
        else
            if is_selected_gcamp
                color = [1, 0, 0]; % rouge
                lineWidth = 1.5;
            else
                color = [0, 0, 0]; % noir
                lineWidth = 0.5;
            end
            tag = 'gcamp';
        end

        % Tracer et rendre cliquable
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