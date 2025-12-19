function [selected_neurons_ordered, selected_gcamp_neurons_original, ...
          selected_blue_neurons_original, suite2p] = ...
    data_checking(data, gcamp_output_folders, current_gcamp_folders_group, ...
                  current_animal_group, current_dates_group, ...
                  current_ages_group, meanImgs_gcamp, checking_choice2)

    % Rendre meanImgs_gcamp optionnel : si pas fourni, le 7e arg est checking_choice2
    if nargin < 8
        checking_choice2 = meanImgs_gcamp;
        meanImgs_gcamp   = [];
    end

    nDates = numel(gcamp_output_folders);

    selected_neurons_ordered        = cell(nDates, 1);
    selected_gcamp_neurons_original = cell(nDates, 1);
    selected_blue_neurons_original  = cell(nDates, 1);

    suite2p   = false;
    global_idx = 0;

    % =====================================================================
    %                          BOUCLE SUR LES GROUPES (m)
    % =====================================================================
    for m = 1:nDates

        fprintf('\n=== DATA CHECKING — DATE %d : %s ===\n', ...
                m, current_dates_group{m});

        % =============================
        % 1) Préparer DF_planes par mode
        % =============================
        switch checking_choice2
            case '1'  % GCaMP only
                DF_planes = data.DF_gcamp_by_plane{m};

            case '2'  % BLUE only
                DF_planes = data.DF_blue_by_plane{m};

            case '3'  % COMBINED (on refait DF_combined par plan ici)
                nPlanes = numel(data.DF_gcamp_by_plane{m});
                DF_planes = cell(nPlanes,1);
                for p = 1:nPlanes
                    DFg = data.DF_gcamp_by_plane{m}{p};
                    DFb = data.DF_blue_by_plane{m}{p};
                    if isempty(DFg); DFg = []; end
                    if isempty(DFb); DFb = []; end
                    DF_planes{p} = [DFg ; DFb];
                end
            otherwise
                error('checking_choice2 invalide : %s', checking_choice2);
        end

        nPlanes = numel(DF_planes);

        % =============================
        % 2) Construire indices globaux par plan
        % =============================
        global_indices_for_plane = cell(nPlanes,1);
        offset = 0;
        for p = 1:nPlanes
            DFp = DF_planes{p};
            if isempty(DFp)
                global_indices_for_plane{p} = [];
                continue;
            end
            nCells_p = size(DFp, 1);
            global_indices_for_plane{p} = (offset+1):(offset+nCells_p);
            offset = offset + nCells_p;
        end

        % agrégateurs pour CE groupe m
        selected_global_all = [];
        selected_blue_all   = [];

        % chemins suite2p pour ce groupe m (optionnel)
        if ~isempty(current_gcamp_folders_group) && m <= numel(current_gcamp_folders_group)
            fall_paths = current_gcamp_folders_group{m};
            if ischar(fall_paths) || isstring(fall_paths)
                fall_paths = {char(fall_paths)};
            end
        else
            fall_paths = {};
        end

        % =================================================================
        %                      BOUCLE SUR LES PLANS (p)
        % =================================================================
        for p = 1:nPlanes

            % -----------------------------------------------------------------
            % 2.1 Charger F_plane / DF_plane / Raster_plane / MAct_plane / outlines
            % -----------------------------------------------------------------
            switch checking_choice2

                %--------------------------- GCaMP ONLY ------------------------%
                case '1'
                    F_plane      = data.F_gcamp_by_plane{m}{p};
                    DF_plane     = data.DF_gcamp_by_plane{m}{p};
                    Raster_plane = data.Raster_gcamp_by_plane{m}{p};
                    MAct_plane   = data.MAct_gcamp_by_plane{m}{p};

                    outline_gcampx_plane    = data.outlines_gcampx_by_plane{m}{p};
                    outline_gcampy_plane    = data.outlines_gcampy_by_plane{m}{p};
                    outline_cellposex_plane = {};
                    outline_cellposey_plane = {};

                    % aucun bleu
                    blue_local_indices_plane = [];

                    batch_size = 30;

                %--------------------------- BLUE ONLY -------------------------%
                case '2'
                    F_plane      = data.F_blue_by_plane{m}{p};
                    DF_plane     = data.DF_blue_by_plane{m}{p};
                    Raster_plane = data.Raster_blue_by_plane{m}{p};
                    MAct_plane   = data.MAct_blue_by_plane{m}{p};

                    outline_gcampx_plane    = {};
                    outline_gcampy_plane    = {};
                    outline_cellposex_plane = data.outlines_x_cellpose_by_plane{m}{p};
                    outline_cellposey_plane = data.outlines_y_cellpose_by_plane{m}{p};

                    if ~isempty(DF_plane)
                        blue_local_indices_plane = (1:size(DF_plane,1)).';
                    else
                        blue_local_indices_plane = [];
                    end

                    batch_size = 5;

                %------------------------ COMBINED GCaMP+BLUE ------------------%
                case '3'
                    % GCaMP
                    Fg      = data.F_gcamp_by_plane{m}{p};
                    DFg     = data.DF_gcamp_by_plane{m}{p};
                    Rg      = data.Raster_gcamp_by_plane{m}{p};
                    MActg   = data.MAct_gcamp_by_plane{m}{p};
                    % BLUE
                    Fb      = data.F_blue_by_plane{m}{p};
                    DFb     = data.DF_blue_by_plane{m}{p};
                    Rb      = data.Raster_blue_by_plane{m}{p};
                    MActb   = data.MAct_blue_by_plane{m}{p};

                    if isempty(Fg);  Fg  = []; end
                    if isempty(DFg); DFg = []; end
                    if isempty(Rg);  Rg  = []; end
                    if isempty(MActg); MActg = []; end

                    if isempty(Fb);  Fb  = []; end
                    if isempty(DFb); DFb = []; end
                    if isempty(Rb);  Rb  = []; end
                    if isempty(MActb); MActb = []; end

                    F_plane      = [Fg ; Fb];
                    DF_plane     = [DFg ; DFb];
                    Raster_plane = [Rg ; Rb];

                    % Pour l'affichage, on prend une MAct combinée simple :
                    % si MActg / MActb existent, on prend max colonne par colonne
                    if ~isempty(MActg) && ~isempty(MActb)
                        len = min(numel(MActg), numel(MActb));
                        MAct_plane = max([MActg(1:len); MActb(1:len)], [], 1);
                    elseif ~isempty(MActg)
                        MAct_plane = MActg;
                    else
                        MAct_plane = MActb;
                    end

                    outline_gcampx_plane    = data.outlines_gcampx_by_plane{m}{p};
                    outline_gcampy_plane    = data.outlines_gcampy_by_plane{m}{p};
                    outline_cellposex_plane = data.outlines_x_cellpose_by_plane{m}{p};
                    outline_cellposey_plane = data.outlines_y_cellpose_by_plane{m}{p};

                    nG = size(DFg,1);
                    nB = size(DFb,1);
                    blue_local_indices_plane = (nG+1):(nG+nB);

                    batch_size = 30;

                otherwise
                    error('checking_choice2 invalide : %s', checking_choice2);
            end

            if isempty(DF_plane)
                continue;
            end

            % Indices globaux pour ce plan AVANT filtrage
            global_indices_for_this_plane = global_indices_for_plane{p};

            %==================================================================
            %   Nettoyage des NaN / indices
            %==================================================================
            valid_neurons_local = any(~isnan(DF_plane), 2);
            DF = DF_plane(valid_neurons_local, :);
            DF(isnan(DF)) = 0;
            F  = F_plane(valid_neurons_local, :);
            Raster = Raster_plane(valid_neurons_local, :);

            valid_local_indices = find(valid_neurons_local);

            global_indices_valid = global_indices_for_this_plane(valid_local_indices);

            %---------------------------- isort1 ----------------------------
            % tri trivial (ordre original)
            if isempty(valid_local_indices)
                continue;
            end
            isort1_full = valid_local_indices(:);
            [~, isort1_plane] = ismember(isort1_full, valid_local_indices);
            total_neurons = length(isort1_plane);

            if total_neurons == 0
                continue;
            end

            num_batches  = ceil(total_neurons / batch_size);
            num_columns  = size(DF, 2);

            %---------------------------- MAct alignée ----------------------
            MAct = MAct_plane;
            if isempty(MAct)
                MAct = zeros(1, num_columns);
            else
                if numel(MAct) < num_columns
                    MAct = [MAct, zeros(1, num_columns - numel(MAct))];
                elseif numel(MAct) > num_columns
                    MAct = MAct(1:num_columns);
                end
            end

            %-------------------- indices bleus GLOBAUX pour ce plan --------
            blue_indices_global = [];
            if ~isempty(blue_local_indices_plane)
                mask_valid_blue = ismember(blue_local_indices_plane, valid_neurons_local);
                blue_local_kept = blue_local_indices_plane(mask_valid_blue);
                [~, pos_in_valid] = ismember(blue_local_kept, valid_local_indices);
                blue_indices_global = global_indices_valid(pos_in_valid);
            end

            %==================================================================
            %   Figure principale (raster)
            %==================================================================
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

            NCell = size(DF, 1);
            prop_MAct = MAct / max(NCell,1);
            plot(ax3, prop_MAct, 'LineWidth', 2);
            xlabel(ax3, 'Frame');
            ylabel(ax3, 'Proportion of Active Cells');
            title(ax3, sprintf('Activity Over Consecutive Frames – Plan %d', p));
            try xlim(ax3, [1 num_columns]); catch; end
            grid(ax3, 'on');

            %==================================================================
            %   Slider pour parcourir les batches
            %==================================================================
            slider_handle = uicontrol('Style', 'slider', ...
                'Min', 1, 'Max', num_batches, 'Value', 1, ...
                'SliderStep', [1/(max(num_batches-1,1)), 1/(max(num_batches-1,1))], ...
                'Units', 'normalized', 'Position', [0.1 0.21 0.85 0.02]);

            %==================================================================
            %   Figure ROI / outlines
            %==================================================================
            gcamp_fig = figure('Name', sprintf('Neuron Visualization – Plan %d', p));
            global_idx = global_idx + 1; % identifiant unique (m,p)

            % meanImg
            meanImg = [];
            if ~isempty(meanImgs_gcamp) && m <= numel(meanImgs_gcamp) && ...
                    ~isempty(meanImgs_gcamp{m}) && p <= numel(meanImgs_gcamp{m})
                meanImg = meanImgs_gcamp{m}{p};
            end

            % Appdata de base
            setappdata(gcamp_fig, 'DF', DF);
            setappdata(gcamp_fig, 'checking_choice2', checking_choice2);
            setappdata(gcamp_fig, 'meanImg', meanImg);
            setappdata(gcamp_fig, 'selected_neurons_total', []);
            setappdata(gcamp_fig, 'neurons_in_batch', []);
            setappdata(gcamp_fig, 'output_index', global_idx);
            setappdata(gcamp_fig, 'parent_figure', main_fig);
            setappdata(gcamp_fig, 'blue_indices', blue_indices_global);

            if ~isempty(fall_paths) && p <= numel(fall_paths)
                setappdata(gcamp_fig, 'current_gcamp_folder', fall_paths{p});
            else
                setappdata(gcamp_fig, 'current_gcamp_folder', '');
            end

            setappdata(gcamp_fig, 'outline_gcampx',    outline_gcampx_plane);
            setappdata(gcamp_fig, 'outline_gcampy',    outline_gcampy_plane);
            setappdata(gcamp_fig, 'outline_cellposex', outline_cellposex_plane);
            setappdata(gcamp_fig, 'outline_cellposey', outline_cellposey_plane);

            %==================================================================
            %   Boutons
            %==================================================================
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

            %==================================================================
            %   Callback slider
            %==================================================================
            slider_handle.Callback = @(src, ~) update_batch_display( ...
                slider_handle, F, DF, isort1_plane, batch_size, ...
                num_columns, ax1, ax1_right, ax2, meanImgs_gcamp, ...
                MAct, blue_indices_global, NCell, m, data, gcamp_fig, valid_local_indices);

            linkaxes([ax1, ax2, ax3], 'x');
            sgtitle(main_fig, ...
                sprintf('%s – %s – %s – Plan %d', ...
                    current_animal_group, current_dates_group{m}, ...
                    current_ages_group{m}, p), ...
                'FontWeight', 'bold');

            %--- Affichage initial ---
            update_batch_display(slider_handle, F, DF, isort1_plane, batch_size, ...
                num_columns, ax1, ax1_right, ax2, meanImgs_gcamp, ...
                MAct, blue_indices_global, NCell, m, data, gcamp_fig, valid_local_indices);

            %==================================================================
            %   Attendre la sélection utilisateur
            %==================================================================
            uiwait(gcamp_fig);

            key = sprintf('selected_result_%d', global_idx);
            if isappdata(0, key)
                selected_local = getappdata(0, key); % indices dans DF (après filtrage)
                rmappdata(0, key);
            else
                selected_local = [];
            end

            % Mapping vers indices globaux
            if ~isempty(selected_local)
                selected_global = global_indices_valid(selected_local);
            else
                selected_global = [];
            end

            % Sélection bleue globale
            if ~isempty(selected_global) && ~isempty(blue_indices_global)
                selected_blue = intersect(selected_global, blue_indices_global);
            else
                selected_blue = [];
            end

            selected_global_all = [selected_global_all, selected_global(:).']; %#ok<AGROW>
            selected_blue_all   = [selected_blue_all,   selected_blue(:).'];   %#ok<AGROW>

        end % boucle plans

        %======================================================================
        %   Finalisation pour ce groupe m
        %======================================================================
        selected_global_all = unique(selected_global_all);
        selected_blue_all   = unique(selected_blue_all);

        selected_gcamp = setdiff(selected_global_all, selected_blue_all);

        selected_neurons_ordered{m}        = selected_global_all;
        selected_gcamp_neurons_original{m} = selected_gcamp;
        selected_blue_neurons_original{m}  = selected_blue_all;

    end % boucle m
end


function update_batch_display(slider_handle, F, DF, isort1, batch_size, num_columns, ...
                              ax1, ax1_right, ax2, meanImgs_gcamp, MAct, blue_indices, ...
                              NCell, m, data, figure_handle, valid_neuron_indices)

    %#ok<INUSD> % beaucoup d'arguments ne sont plus utilisés, mais gardés pour compatibilité

    % Sécurité : figure encore valide ?
    if ~isvalid(figure_handle)
        error('Figure handle invalide !');
    end

    %------------------------------------------------------------------
    % 1) Récupération / initialisation des appdata de sélection
    %------------------------------------------------------------------
    if isappdata(figure_handle, 'selected_neurons_total')
        selected_neurons_total = getappdata(figure_handle, 'selected_neurons_total');
    else
        selected_neurons_total = [];
    end

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

    % Couleurs GCaMP : une couleur par ROI gcamp (basées sur outline_gcampx stockées dans appdata)
    if ~isappdata(figure_handle, 'gcamp_colors')
        outline_gx = [];
        if isappdata(figure_handle, 'outline_gcampx')
            outline_gx = getappdata(figure_handle, 'outline_gcampx');
        end
        if isempty(outline_gx)
            gcamp_colors = [];
        else
            rng(42); % reproductible
            gcamp_colors = rand(numel(outline_gx), 3);
        end
        setappdata(figure_handle, 'gcamp_colors', gcamp_colors);
    end

    % Réécriture (inchangé si existant)
    setappdata(figure_handle, 'selected_neurons_gcamp',    selected_neurons_gcamp);
    setappdata(figure_handle, 'selected_neurons_cellpose', selected_neurons_cellpose);
    setappdata(figure_handle, 'selected_neurons_total',    selected_neurons_total);

    %------------------------------------------------------------------
    % 2) Filtrer isort1 pour exclure les neurones déjà validés
    %------------------------------------------------------------------
    if isempty(selected_neurons_total)
        isort1_filtered = isort1(:);
    else
        isort1_filtered = setdiff(isort1(:), selected_neurons_total(:));
    end

    if isempty(isort1_filtered)
        % Plus aucun neurone à afficher : on peut vider l'axes et sortir
        cla(ax1);
        cla(ax2);
        return;
    end

    %------------------------------------------------------------------
    % 3) Calcul du batch courant
    %------------------------------------------------------------------
    batch_index = round(get(slider_handle, 'Value'));
    batch_index = max(1, min(batch_index, ceil(numel(isort1_filtered)/batch_size)));

    start_idx = (batch_index - 1) * batch_size + 1;
    end_idx   = min(batch_index * batch_size, length(isort1_filtered));

    neurons_in_batch = isort1_filtered(start_idx:end_idx);

    %------------------------------------------------------------------
    % 4) Stockage des infos dans appdata pour les callbacks GUI
    %------------------------------------------------------------------
    setappdata(figure_handle, 'neurons_in_batch', neurons_in_batch);
    setappdata(figure_handle, 'slider_handle',    slider_handle);
    setappdata(figure_handle, 'F',                F);
    setappdata(figure_handle, 'DF',               DF);
    setappdata(figure_handle, 'isort1',           isort1);
    setappdata(figure_handle, 'batch_size',       batch_size);
    setappdata(figure_handle, 'num_columns',      num_columns);
    setappdata(figure_handle, 'ax1',              ax1);
    setappdata(figure_handle, 'ax1_right',        ax1_right);
    setappdata(figure_handle, 'ax2',              ax2);
    setappdata(figure_handle, 'MAct',             MAct);
    setappdata(figure_handle, 'NCell',            size(DF,1));
    setappdata(figure_handle, 'blue_indices',     blue_indices);
    setappdata(figure_handle, 'valid_neuron_indices', valid_neuron_indices);

    % ⚠️ On ne touche plus à 'meanImg', 'outline_gcampx', 'outline_cellposex', etc.
    % Ils sont déjà définis par data_checking pour ce plan.

    %------------------------------------------------------------------
    % 5) Mise à jour des figures annexes (traces + outlines)
    %------------------------------------------------------------------
    if exist('update_gcamp_figure', 'file')
        update_gcamp_figure(figure_handle);
    end
    if exist('update_traces_subplot', 'file')
        update_traces_subplot(figure_handle);
    end

    %------------------------------------------------------------------
    % 6) Mise à jour du raster principal ax1
    %------------------------------------------------------------------
    cla(ax1);
    DF_z = zscore(DF, [], 2);  % z-score par cellule
    imagesc(ax1, DF_z(isort1_filtered, :));

    [minValue, maxValue] = calculate_scaling(DF_z);
    clim(ax1, [minValue, maxValue]);
    colormap(ax1, 'hot');
    axis(ax1, 'tight');

    ax1.XTick = 0:1000:num_columns;
    ax1.XTickLabel = arrayfun(@num2str, 0:1000:num_columns, 'UniformOutput', false);
    xlim(ax1, [1 num_columns]);
    ylabel(ax1, 'Neurons');
    xlabel(ax1, 'Frames');
    set(ax1, 'YDir', 'normal');

    hold(ax1, 'on');
    rectangle(ax1, ...
        'Position', [1, start_idx - 0.5, num_columns, length(neurons_in_batch)], ...
        'EdgeColor', 'c', 'LineWidth', 1.5);
    hold(ax1, 'off');

    % Axe droit (optionnel : index dans le batch, tu peux le réactiver si tu veux)
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
    meanImg             = getappdata(fig_handle, 'meanImg');
    outline_gcampx      = getappdata(fig_handle, 'outline_gcampx');
    outline_gcampy      = getappdata(fig_handle, 'outline_gcampy');
    outline_cellposex   = getappdata(fig_handle, 'outline_cellposex');
    outline_cellposey   = getappdata(fig_handle, 'outline_cellposey');
    neurons_in_batch    = getappdata(fig_handle, 'neurons_in_batch');
    valid_neuron_indices = getappdata(fig_handle, 'valid_neuron_indices');
    selected_total      = getappdata(fig_handle, 'selected_neurons_total');
    checking_choice2    = getappdata(fig_handle, 'checking_choice2');

    if isempty(selected_total), selected_total = []; end
    if isempty(valid_neuron_indices)
        % si pas de mapping, on considère local = original
        valid_neuron_indices = 1:max(neurons_in_batch);
    end

    % --- 2. Axe de tracé ---
    if ~isappdata(fig_handle, 'ax_gcamp')
        ax_gcamp = axes('Parent', fig_handle);
        setappdata(fig_handle, 'ax_gcamp', ax_gcamp);
    else
        ax_gcamp = getappdata(fig_handle, 'ax_gcamp');
    end
    cla(ax_gcamp);
    hold(ax_gcamp, 'on');

    if ~isempty(meanImg)
        imagesc(ax_gcamp, meanImg);
        colormap(ax_gcamp, gray);
        axis(ax_gcamp, 'image');
        set(ax_gcamp, 'YDir', 'reverse');
    end
    title(ax_gcamp, 'Neuron Outlines (aligned)');

    % --- 3. Vérifier le flag de masquage ---
    show_traces = true;
    if isappdata(fig_handle, 'show_selected_traces')
        show_traces = getappdata(fig_handle, 'show_selected_traces');
    end

    % --- 4. Si batch vide ---
    if isempty(neurons_in_batch)
        text(0.5, 0.5, 'No neurons in current batch', 'Parent', ax_gcamp, ...
             'HorizontalAlignment', 'center', 'Color', 'w', 'FontSize', 14);
        hold(ax_gcamp, 'off');
        return;
    end

    % --- 5. Ta logique de structure DF par mode ---
    % Pour COMBINED, on suppose :
    %   - les GCaMP sont 1 : nG
    %   - les BLEUS sont nG+1 : nG+nB
    nG = 0; nB = 0;
    if ~isempty(outline_gcampx)
        nG = numel(outline_gcampx);
    end
    if ~isempty(outline_cellposex)
        nB = numel(outline_cellposex);
    end

    % --- 6. Boucle de tracé ---
    for k = 1:numel(neurons_in_batch)
        local_idx   = neurons_in_batch(k);                 % index dans DF filtré
        if local_idx > numel(valid_neuron_indices)
            continue;
        end
        original_idx = valid_neuron_indices(local_idx);    % index avant filtrage NaN

        % global_idx sert à savoir si ce neurone est dans selected_total
        global_idx = original_idx;

        % Skip si on masque les neurones déjà validés
        if ~show_traces && ismember(global_idx, selected_total)
            continue;
        end

        % Déterminer type (vert / bleu) + index dans les outlines
        is_blue = false;
        idx_g   = [];
        idx_b   = [];

        switch checking_choice2
            case '1'  % GCaMP only
                is_blue = false;
                idx_g   = original_idx;

            case '2'  % BLUE only
                is_blue = true;
                idx_b   = original_idx;

            case '3'  % COMBINED
                if original_idx <= nG
                    % GCaMP
                    is_blue = false;
                    idx_g   = original_idx;
                else
                    % BLUE
                    is_blue = true;
                    idx_b   = original_idx - nG;
                end
        end

        % Couleur et épaisseur selon sélection
        if ismember(global_idx, selected_total)
            col = [1 0 0];   % rouge si déjà validé
            lw  = 2;
        else
            if is_blue
                col = [0 0 1];  % bleu
            else
                col = [0 1 0];  % vert
            end
            lw = 1;
        end

        % Tracé de l'outline, si indices cohérents
        if ~is_blue
            if ~isempty(outline_gcampx) && idx_g >= 1 && idx_g <= numel(outline_gcampx)
                plot(ax_gcamp, outline_gcampx{idx_g}, outline_gcampy{idx_g}, '-', ...
                    'Color', col, 'LineWidth', lw, ...
                    'ButtonDownFcn', @(src, event) neuron_clicked(src, event, global_idx, fig_handle, 'gcamp'));
            end
        else
            if ~isempty(outline_cellposex) && idx_b >= 1 && idx_b <= numel(outline_cellposex)
                plot(ax_gcamp, outline_cellposex{idx_b}, outline_cellposey{idx_b}, '-', ...
                    'Color', col, 'LineWidth', lw, ...
                    'ButtonDownFcn', @(src, event) neuron_clicked(src, event, global_idx, fig_handle, 'cellpose'));
            end
        end
    end

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
                lineWidth = 0.5;
            else
                color = [0, 0, 0]; % noir normal
                lineWidth = 0.5;
            end
            tag = 'cellpose';
        else
            if ismember(cellIndex, selected_total)
                color = [1, 0, 0]; % rouge
                lineWidth = 0.5;
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

    % --- 2. Récupérer DF et fréquence d’échantillonnage ---
    DF = getappdata(gcamp_fig, 'DF');
    sampling_rate = data.sampling_rate{idx};
    valid_neuron_indices = getappdata(gcamp_fig, 'valid_neuron_indices');
    selected_gcamp_neurons_original = valid_neuron_indices(selected_neurons_ordered);

    % --- 3. Préparer la figure ---
    fig = figure('Name', sprintf('Inspection – %s (%s)', ...
        current_animal_group, current_ages_group{idx}));
    screen_size = get(0, 'ScreenSize');
    set(fig, 'Position', [50, 50, screen_size(3)*0.8, screen_size(4)*0.6]);

    % --- 4. Calcul du temps en secondes ---
    Nz = size(DF, 2);
    t_sec = (0:Nz-1) / sampling_rate;

    % --- 5. Tracer les traces ΔF/F ---
    ax = axes(fig);
    hold(ax, 'on');

    n_traces = length(selected_gcamp_neurons_original);
    offset = 0;

    if n_traces == 1
        % Cas 1 : une seule trace → pas de décalage vertical
        cellIdx = selected_gcamp_neurons_original(1);
        trace = DF(cellIdx, :);
        plot(ax, t_sec, trace, 'k', 'LineWidth', 1.2);
        title(ax, sprintf('Trace ΔF/F – Cell %d (%s, %s)', ...
            cellIdx, current_animal_group, current_ages_group{idx}));
        ylabel(ax, '\DeltaF/F');
    else
        % Cas 2 : plusieurs traces → empilement
        for k = 1:n_traces
            cellIdx = selected_gcamp_neurons_original(k);
            trace = DF(cellIdx, :);
            plot(ax, t_sec, trace + offset, 'k', 'LineWidth', 1);
            text(t_sec(end) + (t_sec(end)*0.02), offset, sprintf('Cell %d', cellIdx), ...
                 'Parent', ax, 'Color', 'k', 'FontSize', 8);
            offset = offset + max(trace)*1.5;
        end
        ylabel(ax, '\DeltaF/F (offset)');
        title(ax, sprintf('Traces ΔF/F – %s (%s)', ...
            current_animal_group, current_ages_group{idx}));
    end

    hold(ax, 'off');
    xlabel(ax, 'Time (s)');
    grid(ax, 'on');
    xlim(ax, [0 max(t_sec)]);
end

