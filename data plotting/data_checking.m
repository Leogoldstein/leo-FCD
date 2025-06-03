function selected_neurons_all = data_checking(all_DF, all_isort1, all_MAct, ...
    gcamp_output_folders, current_gcamp_folders_group, ...
    current_animal_group, current_ages_group, meanImgs, ...
    outline_gcampx_all, outline_gcampy_all, ...
    all_data_DF, all_data_isort1, all_data_MAct, ...
    outlines_x_cellpose, outlines_y_cellpose)

    % Initialisation du tableau de résultats (sélections par dossier)
    selected_neurons_all = cell(size(gcamp_output_folders));  % Pour stocker les sélections

    for m = 1:length(gcamp_output_folders)
        try
            if ~isempty(all_data_DF{m})
                DF = all_data_DF{m};
                isort1 = all_data_isort1{m};
                MAct = all_data_MAct{m};  % toujours de gcamp_data apparemment
            else
                DF = all_DF{m};
                isort1 = all_isort1{m};
                MAct = all_MAct{m};
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
    
            % Slider
            slider_handle = uicontrol('Style', 'slider', ...
                'Min', 1, 'Max', num_batches, 'Value', 1, ...
                'SliderStep', [1/(max(num_batches-1,1)), 1/(max(num_batches-1,1))], ...
                'Units', 'normalized', ...
                'Position', [0.1 0.21 0.85 0.02], ...
                'Callback', @(src, ~) update_batch_display(src, DF, isort1, batch_size, ...
                    num_columns, ax1, ax1_right, ax2, ax3, ...
                    meanImgs, outline_gcampx_all, outline_gcampy_all, ...
                    MAct, NCell, m, ...
                    outlines_x_cellpose, outlines_y_cellpose));
    
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
            setappdata(gcamp_fig, 'selected_neurons', []);
            setappdata(gcamp_fig, 'neurons_in_batch', []);
            setappdata(gcamp_fig, 'output_index', m);
            setappdata(gcamp_fig, 'parent_figure', main_fig);
    
            % Initial display
            update_batch_display(slider_handle, DF, isort1, batch_size, ...
                num_columns, ax1, ax1_right, ax2, ax3, ...
                meanImgs, outline_gcampx_all, outline_gcampy_all, ...
                MAct, NCell, m, ...
                outlines_x_cellpose, outlines_y_cellpose);
    
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


function update_batch_display(slider_handle, DF, isort1, batch_size, ...
    num_columns, ax1, ax1_right, ax2, ax3, ...
    meanImgs, outline_gcampx_all, outline_gcampy_all, ...
    MAct, NCell, m, ...
    outlines_x_cellpose, outlines_y_cellpose)

    batch_index = round(get(slider_handle, 'Value'));
    start_idx = (batch_index - 1) * batch_size + 1;
    end_idx = min(batch_index * batch_size, length(isort1));
    neurons_in_batch = isort1(start_idx:end_idx);

    % --- Mise à jour appdata GCaMP Figure (création ou récupération) ---
    figure_handle = findobj('Type', 'figure', 'Name', 'GCaMP Figure');
    if isempty(figure_handle)
        figure_handle = figure('Name', 'GCaMP Figure');
        setappdata(figure_handle, 'meanImg', meanImgs{m});
        setappdata(figure_handle, 'outline_gcampx', outline_gcampx_all{m});
        setappdata(figure_handle, 'outline_gcampy', outline_gcampy_all{m});
        setappdata(figure_handle, 'selected_neurons', []);
        setappdata(fig_handle, 'outline_cellposex', outlines_x_cellpose{m});
        setappdata(fig_handle, 'outline_cellposey', outlines_y_cellpose{m});
    else
        figure(figure_handle);
    end
    % Stocke batch courant pour affichage verts
    setappdata(figure_handle, 'neurons_in_batch', neurons_in_batch);

    % --------- Subplot 2: Traces dans ordre normal -------------
    cla(ax2); hold(ax2, 'on');
    vertical_offset = 0;
    yticks_pos = [];
    yticklabels_list = [];
    
    for i = 1:length(neurons_in_batch)
        cellIndex = neurons_in_batch(i);
        trace = DF(cellIndex, :);

        % Vérifie si ce neurone est sélectionné
        selected_neurons = getappdata(figure_handle, 'selected_neurons');
        if ismember(cellIndex, selected_neurons)
            color = 'r';  % rouge pour les neurones sélectionnés
            linewidth = 1.5;
        else
            color = 'k';  % noir sinon
            linewidth = 0.5;
        end
        
        h = plot(ax2, trace + vertical_offset, color, 'LineWidth', linewidth);

        % Ajout callback clic sur trace :
        set(h, 'ButtonDownFcn', @(src, event) neuron_clicked(src, event, cellIndex, figure_handle));
        
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

    % --- Subplot 1 : Raster + rectangle batch + axe secondaire ------
    cla(ax1);
    imagesc(ax1, DF(isort1, :));
    [minValue, maxValue] = calculate_scaling(DF);
    clim([minValue, maxValue]);
    colormap(ax1, 'hot');
    axis(ax1, 'tight');
    ax1.XTick = 0:1000:num_columns;
    ax1.XTickLabel = arrayfun(@num2str, 0:1000:num_columns, 'UniformOutput', false);
    xlim(ax1, [0 num_columns]);
    ylabel(ax1, 'Neurons');
    xlabel(ax1, 'Frames');
    set(ax1, 'YDir', 'normal');

    hold(ax1, 'on');
    y_start = start_idx - 0.5;
    y_height = length(neurons_in_batch);
    rectangle(ax1, 'Position', [0, y_start, num_columns, y_height], 'EdgeColor', 'c', 'LineWidth', 1.5);
    hold(ax1, 'off');

    % Axe y droit : indices neurones batch courant
    cla(ax1_right);
    ax1_right.YLim = ax1.YLim;
    ax1_right.XLim = ax1.XLim;
    ax1_right.YTick = start_idx:end_idx;
    ax1_right.YTickLabel = arrayfun(@num2str, neurons_in_batch, 'UniformOutput', false);
    ax1_right.XTick = [];
    ax1_right.YDir = 'normal';
    ylabel(ax1_right, 'Batch Neuron IDs');

    % --- Subplot 3 : Proportion cellules actives -----
    cla(ax3);
    prop_MAct = MAct / NCell;
    plot(ax3, prop_MAct, 'LineWidth', 2);
    xlabel(ax3, 'Frame');
    ylabel(ax3, 'Proportion of Active Cells');
    title(ax3, 'Activity Over Consecutive Frames');
    xlim(ax3, [0 num_columns]);
    grid(ax3, 'on');

    % --- Mise à jour figure GCaMP ---
    update_gcamp_figure(figure_handle);
    
    % Enregistrer les handles et variables utiles pour les mises à jour ultérieures
    setappdata(figure_handle, 'ax2', ax2);
    setappdata(figure_handle, 'DF', DF);
    setappdata(figure_handle, 'num_columns', num_columns);

end


function update_gcamp_figure(fig_handle)
    meanImg = getappdata(fig_handle, 'meanImg');
    outline_gcampx = getappdata(fig_handle, 'outline_gcampx');
    outline_gcampy = getappdata(fig_handle, 'outline_gcampy');
    outline_cellposex = getappdata(fig_handle, 'outline_cellposex');
    outline_cellposey = getappdata(fig_handle, 'outline_cellposey');
    selected_neurons = getappdata(fig_handle, 'selected_neurons');
    neurons_in_batch = getappdata(fig_handle, 'neurons_in_batch');

    if isempty(selected_neurons)
        selected_neurons = [];
    end

    figure(fig_handle);
    clf;
    hold on;
    imagesc(meanImg);
    colormap(gca, gray);
    axis image;
    set(gca, 'YDir', 'reverse');
    title('GCaMP outlines');

    % Désactiver les clics sur l’image (sinon elle bloque les clics)
    img_handle = get(gca, 'Children');
    set(img_handle(1), 'HitTest', 'off');

    % --- Contours BLEUS (cellpose) ET VERTS (GCaMP) des neurones du batch
    for n = 1:length(neurons_in_batch)
        idx = neurons_in_batch(n);
        
        % Contours bleus Cellpose
        if idx <= length(outline_cellposex) && idx <= length(outline_cellposey)
             h = plot(outline_cellposex{idx}, outline_cellposey{idx}, '.', ...
                     'MarkerSize', 1, 'Color', 'b');
            set(h, 'ButtonDownFcn', @(src, event) neuron_clicked(src, event, idx, fig_handle));
            set(h, 'HitTest', 'on', 'PickableParts', 'all');
        end
        
        % Contours verts GCaMP
        if idx <= length(outline_gcampx) && idx <= length(outline_gcampy)
            h = plot(outline_gcampx{idx}, outline_gcampy{idx}, '.', ...
                     'MarkerSize', 1, 'Color', 'g');
            set(h, 'ButtonDownFcn', @(src, event) neuron_clicked(src, event, idx, fig_handle));
            set(h, 'HitTest', 'on', 'PickableParts', 'all');
        end
    end

    % Contours rouges (neurones sélectionnés)
    for idx = selected_neurons
        if idx <= length(outline_gcampx) && idx <= length(outline_gcampy)
            h = plot(outline_gcampx{idx}, outline_gcampy{idx}, '.', ...
                     'MarkerSize', 7, 'Color', 'r', 'LineWidth', 1.5);
            set(h, 'ButtonDownFcn', @(src, event) neuron_clicked(src, event, idx, fig_handle));
            set(h, 'HitTest', 'on', 'PickableParts', 'all');
        end
    end

    hold off;
end

function neuron_clicked(src, ~, idx, gcamp_fig)
    click_type = get(gcbf, 'SelectionType');  % 'normal' = gauche, 'alt' = clic droit

    disp(['Clicked neuron ', num2str(idx), ' with click type: ', get(gcbf, 'SelectionType')]);

    selected_neurons = getappdata(gcamp_fig, 'selected_neurons');
    if isempty(selected_neurons)
        selected_neurons = [];
    end

    if strcmp(click_type, 'normal')  % Clic gauche : sélectionne
        if ~ismember(idx, selected_neurons)
            selected_neurons(end+1) = idx;
        end
    elseif strcmp(click_type, 'alt')  % Clic droit : désélectionne
        if ismember(idx, selected_neurons)
            selected_neurons(selected_neurons == idx) = [];
        end
    end

    setappdata(gcamp_fig, 'selected_neurons', selected_neurons);

    % Met à jour les deux vues
    update_gcamp_figure(gcamp_fig);
    update_traces_subplot(gcamp_fig);
end



function update_traces_subplot(gcamp_fig)
    ax2 = getappdata(gcamp_fig, 'ax2');
    DF = getappdata(gcamp_fig, 'DF');
    neurons_in_batch = getappdata(gcamp_fig, 'neurons_in_batch');
    num_columns = getappdata(gcamp_fig, 'num_columns');
    selected_neurons = getappdata(gcamp_fig, 'selected_neurons');

    cla(ax2); hold(ax2, 'on');
    vertical_offset = 0;
    yticks_pos = [];
    yticklabels_list = [];

    for i = 1:length(neurons_in_batch)
        cellIndex = neurons_in_batch(i);
        trace = DF(cellIndex, :);

        if ismember(cellIndex, selected_neurons)
            color = 'r'; linewidth = 1.5;
        else
            color = 'k'; linewidth = 0.5;
        end

        h = plot(ax2, trace + vertical_offset, color, 'LineWidth', linewidth);
        set(h, 'ButtonDownFcn', @(src, event) neuron_clicked(src, event, cellIndex, gcamp_fig));

        yticks_pos(end+1) = vertical_offset + max(trace)/2;
        yticklabels_list{end+1} = num2str(cellIndex);
        vertical_offset = vertical_offset + max(trace) * 1.2;
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