function [F0, noise_est, valid_cells, DF_sg, DF_raw, Raster, ...
          Acttmp2, MAct, thresholds, focus_segs, opts, ...
          has_new_outputs, request_reprocess, selected_signal] = ...
    peak_detection_tuner( ...
        type, ...
        line, ...
        animal, ...
        date, ...
        age, ...
        plane, ...
        F, ...
        fs, ...
        synchronous_frames, ...
        viewer_mode, ...
        DF_sg, ...
        DF_raw, ...
        F0, ...
        noise_est, ...
        Acttmp2, ...
        Raster, ...
        thresholds, ...
        valid_cells, ...
        cell_type, ...
        ops, ...
        iscell_idx, ...
        stat, ...
        masks, ...
        electroporated_indices, ...
        meanImg, ...
        gcamp_TSeries_path, ...
        deviation, ...
        bad_frames, ...
        focus_segs, ...
        motion_energy, ...
        metadata, ...
        stim_frames, ...
        gcamp_output_folder, ...
        output_folder)

    %==============================================================
    % Options
    %==============================================================

    opts = struct( ...
        'window_size_s',         120, ...
        'savgol_win_ms',         300, ...
        'savgol_poly',             3, ...
        'refrac_ms',             300, ...
        'prominence_factor',       1, ...
        'min_n_peaks_cutoff',     10, ...
        'min_mask_um2',           50, ...
        'min_mask_connectivity', 0.80);

    opts = ...
        convert_opts_ms_to_frames( ...
            opts, ...
            fs);

    request_reprocess = false;

    %==============================================================
    % PREPROCESSING
    %==============================================================

    window_size = ...
        opts.window_size;

    if viewer_mode

        if ~isempty(DF_sg) && ...
                size(DF_sg,1) == size(F,1)

            if isempty(F0) || ...
                    size(F0,1) ~= size(F,1)

                F0 = ...
                    nan(size(F));
            end

            if ~isempty(noise_est) && ...
                    numel(noise_est) == size(F,1)

                noise_est = ...
                    noise_est(:);

            else

                noise_est = ...
                    estimate_noise(DF_sg);
            end

            if isempty(DF_raw) || ...
                    size(DF_raw,1) ~= size(F,1)

                DF_raw = [];
            end

            [ ...
                ~, ...
                SNR, ...
                score, ...
                cells_sorted_by_quality, ...
                ~, ...
                ~, ...
                ~ ...
            ] = ...
                compute_snr_quality( ...
                    DF_sg, ...
                    noise_est, ...
                    opts, ...
                    bad_frames);

        else

            warning( ...
                ['viewer_mode demandé mais DF_sg sauvegardé ' ...
                 'absent/incompatible. Recalcul normal.']);

            viewer_mode = false;
        end
    end

    if ~viewer_mode

        [DF_raw, F0] = ...
            F_processing( ...
                F, ...
                bad_frames, ...
                fs, ...
                window_size);

        DF_sg = ...
            savgol_transform( ...
                DF_raw, ...
                opts);

        noise_est = ...
            estimate_noise( ...
                DF_raw);

        [ ...
            ~, ...
            SNR, ...
            score, ...
            cells_sorted_by_quality, ...
            ~, ...
            ~, ...
            ~ ...
        ] = ...
            compute_snr_quality( ...
                DF_sg, ...
                noise_est, ...
                opts, ...
                bad_frames);
    end

    %==============================================================
    % POPULATIONS
    %
    % F est normalement F_combined.
    %
    % Combined       = toutes les cellules
    % Electroporated = electroporated_indices
    % GCaMP          = complément
    %
    % Aucun recalcul de DF/F0 lors d'un changement de population.
    %==============================================================

    nCells = ...
        size(F,1);

    electroporated_indices = ...
        normalize_electroporated_indices( ...
            electroporated_indices, ...
            nCells);

    if strcmpi(cell_type, 'combined')

        selected_signal = ...
            'combined';

    elseif strcmpi(cell_type, 'electroporated')

        selected_signal = ...
            'electroporated';

    else

        selected_signal = ...
            'gcamp';
    end

    %==============================================================
    % TITRE
    %==============================================================

    title_parts = {};

    if viewer_mode
        title_parts{end+1} = '[VIEWER MODE]';
    end

    title_parts{end+1} = ...
        upper(selected_signal);

    if ~isempty(gcamp_output_folder)

        title_parts{end+1} = ...
            char(string(gcamp_output_folder));

    elseif ~isempty(gcamp_TSeries_path)

        title_parts{end+1} = ...
            char( ...
                string( ...
                    fileparts(gcamp_TSeries_path)));
    end

    title_parts{end+1} = ...
        sprintf( ...
            'nCells=%d', ...
            nCells);

    winTitle = ...
        strjoin( ...
            title_parts, ...
            ' | ');

    %==============================================================
    % GUI
    %==============================================================

    fig = ...
        figure( ...
            'Name', winTitle, ...
            'NumberTitle', 'off', ...
            'Position', [100 100 1300 820], ...
            'Color', [.97 .97 .98]);

    set( ...
        fig, ...
        'KeyPressFcn', ...
        @(~,evnt) navigate_cells(fig, evnt));

    set( ...
        fig, ...
        'CloseRequestFcn', ...
        @(src,~) uiresume(src));

    ctrl_panel = ...
        uipanel( ...
            'Parent', fig, ...
            'Units', 'normalized', ...
            'Position', [0.01 0.05 0.22 0.92], ...
            'Title', 'Contrôles', ...
            'FontSize', 10, ...
            'Tag', 'ctrl_panel');

    %==============================================================
    % APPDATA GLOBAL
    %==============================================================

    setappdata(fig, 'fs', fs);

    setappdata(fig, 'F_raw', F);

    setappdata(fig, 'DF_sg', DF_sg);
    setappdata(fig, 'DF_raw', DF_raw);
    setappdata(fig, 'F0', F0);

    setappdata(fig, 'noise_est', noise_est);

    setappdata(fig, 'SNR', SNR);
    setappdata(fig, 'score_quality', score);

    setappdata(fig, 'opts', opts);

    setappdata(fig, 'selected_signal', selected_signal);

    setappdata( ...
        fig, ...
        'electroporated_indices', ...
        electroporated_indices);

    setappdata(fig, 'viewer_mode', viewer_mode);

    %==============================================================
    % Sélection GLOBAL COMBINED
    %
    % manual_status :
    %   0  = aucune décision
    %   +1 = keep manuel
    %   -1 = exclude manuel
    %
    % cutoff_status :
    %   0  = cutoff non évalué
    %   +1 = passe cutoff
    %   -1 = échoue cutoff
    %
    % Les deux utilisent TOUJOURS les indices Combined.
    %==============================================================

    setappdata( ...
        fig, ...
        'manual_status', ...
        zeros(nCells,1));

    setappdata( ...
        fig, ...
        'cutoff_status', ...
        zeros(nCells,1));

    setappdata( ...
        fig, ...
        'cutoff_validated', ...
        false);

    setappdata( ...
        fig, ...
        'cutoff_locked', ...
        false);

    %==============================================================
    % QUALITY PERCENTILE
    %==============================================================

    score_quality_percentile = ...
        nan(size(score));

    valid_score = ...
        isfinite(score);

    [~, order_score] = ...
        sort( ...
            score(valid_score), ...
            'ascend');

    tmp = ...
        nan( ...
            sum(valid_score), ...
            1);

    if ~isempty(tmp)

        tmp(order_score) = ...
            linspace( ...
                0, ...
                100, ...
                sum(valid_score));
    end

    score_quality_percentile(valid_score) = ...
        tmp;

    setappdata( ...
        fig, ...
        'score_quality_percentile', ...
        score_quality_percentile);

    %==============================================================
    % AUTRES APPDATA
    %==============================================================

    setappdata(fig, 'motion_energy', motion_energy);

    setappdata(fig, 'deviation', deviation);
    setappdata(fig, 'bad_frames', bad_frames);
    setappdata(fig, 'focus_segs', focus_segs);

    setappdata(fig, 'stim_frames', stim_frames);

    setappdata( ...
        fig, ...
        'cells_sorted_by_quality', ...
        cells_sorted_by_quality);

    setappdata(fig, 'stat', stat);
    setappdata(fig, 'meanImg', meanImg);
    setappdata(fig, 'metadata', metadata);

    setappdata(fig, 'gcamp_output_folder', gcamp_output_folder);
    setappdata(fig, 'output_folder', output_folder);

    setappdata(fig, 'cell_type', cell_type);

    setappdata( ...
        fig, ...
        'initial_cell_count', ...
        nCells);

    setappdata(fig, 'gcamp_TSeries_path', gcamp_TSeries_path);

    setappdata(fig, 'type', type);
    setappdata(fig, 'line', line);
    setappdata(fig, 'animal', animal);
    setappdata(fig, 'date', date);
    setappdata(fig, 'age', age);
    setappdata(fig, 'plane', plane);

    setappdata( ...
        fig, ...
        'total_frame_count', ...
        size(F,2));

    setappdata(fig, 'masks', masks);

    %==============================================================
    % VIEWER SAVED DATA
    %==============================================================

    setappdata(fig, 'Raster_saved', Raster);
    setappdata(fig, 'Acttmp2_saved', Acttmp2);
    setappdata(fig, 'thresholds_saved', thresholds);
    setappdata(fig, 'valid_cells_saved', valid_cells);

    %==============================================================
    % ISCELL DISPLAY
    %==============================================================

    iscell_idx_display = ...
        nan(nCells,1);

    if ~isempty(iscell_idx)

        iscell_idx = ...
            iscell_idx(:);

        if strcmpi(cell_type,'combined') && ...
                ~isempty(electroporated_indices)

            is_electroporated = ...
                false(nCells,1);

            is_electroporated( ...
                electroporated_indices) = true;

            gcamp_rows = ...
                find( ...
                    ~is_electroporated);

            n = ...
                min( ...
                    numel(gcamp_rows), ...
                    numel(iscell_idx));

            iscell_idx_display( ...
                gcamp_rows(1:n)) = ...
                iscell_idx(1:n);

        else

            n = ...
                min( ...
                    nCells, ...
                    numel(iscell_idx));

            iscell_idx_display(1:n) = ...
                iscell_idx(1:n);
        end
    end

    setappdata( ...
        fig, ...
        'iscell_idx_display', ...
        iscell_idx_display);

    %==============================================================
    % MASK METRICS
    %==============================================================

    pixel_size_um = NaN;

    mask_sizes = ...
        nan(nCells,1);

    mask_connectivity_ratio = ...
        nan(nCells,1);

    if ~isempty(masks) && ...
            (isnumeric(masks) || islogical(masks)) && ...
            ndims(masks) >= 3

        try

            if isstruct(metadata) && ...
                    isfield(metadata,'PixelSize_um') && ...
                    ~isempty(metadata.PixelSize_um)

                px = ...
                    metadata.PixelSize_um;

                if isnumeric(px)

                    pixel_size_um = ...
                        double(px(1));

                elseif iscell(px) && ...
                        ~isempty(px)

                    pixel_size_um = ...
                        double(px{1});
                end
            end

        catch

            pixel_size_um = NaN;
        end

        nCells_masks = ...
            min( ...
                size(masks,1), ...
                nCells);

        for i = 1:nCells_masks

            current_mask = ...
                squeeze(masks(i,:,:)) > 0;

            if isempty(current_mask) || ...
                    ~any(current_mask(:))

                continue;
            end

            npix = ...
                sum(current_mask(:));

            if isfinite(pixel_size_um) && ...
                    pixel_size_um > 0

                mask_sizes(i) = ...
                    npix * ...
                    pixel_size_um^2;
            end

            CC = ...
                bwconncomp( ...
                    current_mask, ...
                    8);

            if CC.NumObjects > 0

                comp_sizes = ...
                    cellfun( ...
                        @numel, ...
                        CC.PixelIdxList);

                mask_connectivity_ratio(i) = ...
                    max(comp_sizes) / ...
                    sum(comp_sizes);
            end
        end
    end

    setappdata(fig, 'pixel_size_um', pixel_size_um);
    setappdata(fig, 'mask_sizes', mask_sizes);

    setappdata( ...
        fig, ...
        'mask_connectivity_ratio', ...
        mask_connectivity_ratio);

    %==============================================================
    % CALLBACKS
    %==============================================================

    if viewer_mode

        validate_cb = @(~,~) [];
        keep_cb = @(~,~) [];
        exclude_cb = @(~,~) [];

    else

        validate_cb = ...
            @(~,~) validate_selection_filter(fig);

        keep_cb = ...
            @(~,~) keep_cell(fig);

        exclude_cb = ...
            @(~,~) exclude_cell(fig);
    end

    finalize_cb = ...
        @(~,~) finalize_and_close( ...
            fig, ...
            synchronous_frames);

    %==============================================================
    % NAVIGATION
    %==============================================================

    uicontrol( ...
        'Parent', ctrl_panel, ...
        'Style', 'text', ...
        'String', sprintf('Navigation cellule (1 / %d)', nCells), ...
        'Units', 'normalized', ...
        'Position', [0.05 0.935 0.90 0.03], ...
        'Tag', 'lbl_nav_cell', ...
        'HorizontalAlignment', 'left', ...
        'BackgroundColor', [.97 .97 .98], ...
        'FontWeight', 'bold');

    if nCells > 1

        step_small = ...
            1 / (nCells - 1);

        step_big = ...
            min( ...
                1, ...
                10 / (nCells - 1));

    else

        step_small = 1;
        step_big = 1;
    end

    uicontrol( ...
        'Parent', ctrl_panel, ...
        'Style', 'slider', ...
        'Min', 1, ...
        'Max', max(1,nCells), ...
        'Value', 1, ...
        'SliderStep', [step_small step_big], ...
        'Units', 'normalized', ...
        'Position', [0.05 0.865 0.90 0.055], ...
        'Tag', 'sldr_nav_cell', ...
        'Callback', ...
        @(src,~) update_current_cell( ...
            fig, ...
            round(get(src,'Value'))));

    %==============================================================
    % POPULATION CHECKBOXES
    %==============================================================

    signal_panel = ...
        uipanel( ...
            'Parent', ctrl_panel, ...
            'Units', 'normalized', ...
            'Position', [0.05 0.775 0.90 0.075], ...
            'Title', 'Population', ...
            'FontSize', 9);

    has_electroporated_population = ...
        ~isempty(electroporated_indices);

    has_gcamp_population = ...
        numel(electroporated_indices) < nCells;

    if strcmpi(cell_type,'combined')

        enable_gcamp = ...
            on_off(has_gcamp_population);

        enable_electroporated = ...
            on_off(has_electroporated_population);

        enable_combined = ...
            'on';

    elseif strcmpi(cell_type,'electroporated')

        enable_gcamp = 'off';
        enable_electroporated = 'on';
        enable_combined = 'off';

    else

        enable_gcamp = 'on';
        enable_electroporated = 'off';
        enable_combined = 'off';
    end

    uicontrol( ...
        'Parent', signal_panel, ...
        'Style', 'checkbox', ...
        'String', 'GCaMP', ...
        'Units', 'normalized', ...
        'Position', [0.02 0.08 0.27 0.78], ...
        'Value', strcmp(selected_signal,'gcamp'), ...
        'Enable', enable_gcamp, ...
        'Tag', 'cb_population_gcamp', ...
        'Callback', ...
        @(src,~) select_population_checkbox( ...
            fig, ...
            src, ...
            'gcamp'));

    uicontrol( ...
        'Parent', signal_panel, ...
        'Style', 'checkbox', ...
        'String', 'Electroporated', ...
        'Units', 'normalized', ...
        'Position', [0.30 0.08 0.40 0.78], ...
        'Value', strcmp(selected_signal,'electroporated'), ...
        'Enable', enable_electroporated, ...
        'Tag', 'cb_population_electroporated', ...
        'Callback', ...
        @(src,~) select_population_checkbox( ...
            fig, ...
            src, ...
            'electroporated'));

    uicontrol( ...
        'Parent', signal_panel, ...
        'Style', 'checkbox', ...
        'String', 'Combined', ...
        'Units', 'normalized', ...
        'Position', [0.70 0.08 0.28 0.78], ...
        'Value', strcmp(selected_signal,'combined'), ...
        'Enable', enable_combined, ...
        'Tag', 'cb_population_combined', ...
        'Callback', ...
        @(src,~) select_population_checkbox( ...
            fig, ...
            src, ...
            'combined'));

    %==============================================================
    % SLIDERS
    %==============================================================

    make_slider( ...
        ctrl_panel, ...
        fig, ...
        'Window size (sec)', ...
        'window_size_s', ...
        1, ...
        300, ...
        opts.window_size_s, ...
        [0.05 0.68 0.90 0.06]);

    make_slider( ...
        ctrl_panel, ...
        fig, ...
        'Prominence', ...
        'prominence_factor', ...
        0, ...
        1, ...
        1, ...
        [0.05 0.57 0.90 0.06]);

    make_slider( ...
        ctrl_panel, ...
        fig, ...
        'Réfractaire (ms)', ...
        'refrac_ms', ...
        0, ...
        5000, ...
        opts.refrac_ms, ...
        [0.05 0.49 0.90 0.06]);

    make_slider( ...
        ctrl_panel, ...
        fig, ...
        'SavGol window (ms)', ...
        'savgol_win_ms', ...
        100, ...
        500, ...
        opts.savgol_win_ms, ...
        [0.05 0.41 0.90 0.06]);

    %==============================================================
    % BOUTONS
    %==============================================================

    uicontrol( ...
        'Parent', ctrl_panel, ...
        'Style', 'pushbutton', ...
        'String', 'Reprocess', ...
        'Units', 'normalized', ...
        'Position', [0.05 0.235 0.90 0.055], ...
        'Tag', 'btn_reprocess', ...
        'Callback', ...
        @(~,~) request_reprocess_from_viewer(fig));

    uicontrol( ...
        'Parent', ctrl_panel, ...
        'Style', 'pushbutton', ...
        'String', 'Appliquer cutoff', ...
        'Units', 'normalized', ...
        'Position', [0.05 0.17 0.90 0.055], ...
        'BackgroundColor', [0.20 0.45 0.90], ...
        'ForegroundColor', 'w', ...
        'FontWeight', 'bold', ...
        'FontSize', 12, ...
        'Tag', 'btn_apply_cutoff', ...
        'Callback', validate_cb);
    
    uicontrol( ...
        'Parent', ctrl_panel, ...
        'Style', 'pushbutton', ...
        'String', 'Confirmer sélection', ...
        'Units', 'normalized', ...
        'Position', [0.05 0.02 0.90 0.06], ...
        'BackgroundColor', [0.1 0.6 0.35], ...
        'ForegroundColor', 'w', ...
        'FontWeight', 'bold', ...
        'FontSize', 12, ...
        'Tag', 'btn_confirm_selection', ...
        'Callback', finalize_cb);

    uicontrol( ...
        'Parent', ctrl_panel, ...
        'Style', 'pushbutton', ...
        'String', 'Garder cellule', ...
        'Units', 'normalized', ...
        'Position', [0.05 0.095 0.42 0.055], ...
        'BackgroundColor', [0.10 0.60 0.10], ...
        'ForegroundColor', 'w', ...
        'FontWeight', 'bold', ...
        'FontSize', 11, ...
        'Callback', keep_cb);

    uicontrol( ...
        'Parent', ctrl_panel, ...
        'Style', 'pushbutton', ...
        'String', 'Exclure cellule', ...
        'Units', 'normalized', ...
        'Position', [0.53 0.095 0.42 0.055], ...
        'BackgroundColor', [0.80 0.15 0.15], ...
        'ForegroundColor', 'w', ...
        'FontWeight', 'bold', ...
        'FontSize', 11, ...
        'Callback', exclude_cb);

    if viewer_mode

        set( ...
            findobj(ctrl_panel,'String','Appliquer cutoff'), ...
            'Enable','off');

        set( ...
            findobj(ctrl_panel,'String','Garder cellule'), ...
            'Enable','off');

        set( ...
            findobj(ctrl_panel,'String','Exclure cellule'), ...
            'Enable','off');

        set( ...
            findobj(ctrl_panel,'String','Confirmer sélection'), ...
            'Enable','off');

        set( ...
            findobj(ctrl_panel,'String','Reprocess'), ...
            'Enable','on');

    else

        set( ...
            findobj(ctrl_panel,'String','Reprocess'), ...
            'Enable','off');
    end
    
    update_population_action_buttons(fig);
    
    %==============================================================
    % AXES
    %==============================================================

    ax1 = ...
        axes( ...
            'Parent', fig, ...
            'Position', [0.28 0.63 0.70 0.30]);

    box(ax1,'on');

    xlabel(ax1,'Frames');
    ylabel(ax1,'\DeltaF/F (SavGol)');

    plot(ax1,NaN,NaN,'k-');
    hold(ax1,'on');

    axF0 = ...
        axes( ...
            'Parent', fig, ...
            'Position', [0.28 0.55 0.70 0.06]);

    box(axF0,'on');
    ylabel(axF0,'F0');
    set(axF0,'XTickLabel',[]);
    hold(axF0,'on');

    axDev = ...
        axes( ...
            'Parent', fig, ...
            'Position', [0.28 0.47 0.70 0.06]);

    box(axDev,'on');
    ylabel(axDev,'Dev');
    set(axDev,'XTickLabel',[]);
    hold(axDev,'on');

    axMotion = ...
        axes( ...
            'Parent', fig, ...
            'Position', [0.28 0.41 0.70 0.045]);

    box(axMotion,'on');
    ylabel(axMotion,'Motion');
    set(axMotion,'XTickLabel',[]);
    hold(axMotion,'on');

    axROI = ...
        axes( ...
            'Parent', fig, ...
            'Position', [0.28 0.06 0.30 0.30]);

    box(axROI,'on');
    title(axROI,'ROI (zoom)');
    axis(axROI,'image');

    axH = ...
        axes( ...
            'Parent', fig, ...
            'Position', [0.62 0.06 0.35 0.30]);

    box(axH,'on');
    title(axH,'# pics / cellule');
    xlabel(axH,'Nombre de pics');
    ylabel(axH,'Nombre de cellules');

    setappdata(fig,'ax1',ax1);
    setappdata(fig,'axF0',axF0);
    setappdata(fig,'axDev',axDev);
    setappdata(fig,'axMotion',axMotion);
    setappdata(fig,'axROI',axROI);
    setappdata(fig,'axH',axH);

    %==============================================================
    % MOTION DISPLAY
    %==============================================================

    dev = ...
        deviation(:).';

    if ~isempty(dev)

        plot( ...
            axDev, ...
            1:numel(dev), ...
            dev, ...
            'k-', ...
            'HitTest','off');

        dv = ...
            dev(isfinite(dev));

        if ~isempty(dv)

            lo = prctile(dv,2);
            hi = prctile(dv,98);

            if isfinite(lo) && ...
                    isfinite(hi) && ...
                    hi > lo

                pad = ...
                    0.1 * ...
                    (hi - lo);

                ylim( ...
                    axDev, ...
                    [lo-pad hi+pad]);
            end
        end

    else

        text( ...
            axDev, ...
            0.5, ...
            0.5, ...
            'deviation vide', ...
            'Units','normalized', ...
            'HorizontalAlignment','center');
    end

    if ~isempty(motion_energy)

        motion_energy = ...
            motion_energy(:).';

        plot( ...
            axMotion, ...
            1:numel(motion_energy), ...
            motion_energy, ...
            'k-', ...
            'HitTest','off');

    else

        text( ...
            axMotion, ...
            0.5, ...
            0.5, ...
            'motion energy vide', ...
            'Units','normalized', ...
            'HorizontalAlignment','center');
    end

    if ~isempty(focus_segs)

        hBad1 = ...
            create_badframe_patch( ...
                ax1, ...
                focus_segs);

        setappdata(fig,'hBadPatch_ax1',hBad1);

        hBadF0 = ...
            create_badframe_patch( ...
                axF0, ...
                focus_segs);

        setappdata(fig,'hBadPatch_axF0',hBadF0);

        hBadDev = ...
            create_badframe_patch( ...
                axDev, ...
                focus_segs);

        setappdata(fig,'hBadPatch_axDev',hBadDev);

        hBadMotion = ...
            create_badframe_patch( ...
                axMotion, ...
                focus_segs);

        setappdata(fig,'hBadPatch_axMotion',hBadMotion);
    end

    linkaxes( ...
        [ax1 axF0 axDev axMotion], ...
        'x');

    %==============================================================
    % PEAK COUNTS
    %==============================================================

    if viewer_mode

        n_peaks_all = ...
            zeros(nCells,1);

        if ~isempty(Acttmp2)

            for cid = 1:min(nCells,numel(Acttmp2))

                if iscell(Acttmp2)

                    n_peaks_all(cid) = ...
                        numel(Acttmp2{cid});
                end
            end

        elseif ~isempty(Raster)

            n_peaks_all = ...
                sum( ...
                    logical(Raster), ...
                    2);

            n_peaks_all = ...
                n_peaks_all(:);
        end

        setappdata(fig,'n_peaks_all',n_peaks_all);

        % Viewer : aucun cutoff
        setappdata(fig,'cutoff_validated',false);
        setappdata(fig,'cutoff_locked',true);

    else

        recompute_n_peaks_all(fig);

        % IMPORTANT :
        % on ne déclenche PAS automatiquement apply_auto_cutoff ici.
        %
        % Le bouton "Appliquer cutoff" doit réellement appliquer
        % les critères.
    end

    %==============================================================
    % INITIALISER NAVIGATION
    %==============================================================

    refresh_selection_order(fig);

    if isappdata(fig,'order_cells')

        order_cells = ...
            getappdata(fig,'order_cells');

        if ~isempty(order_cells)

            update_current_cell(fig,1);
        end
    end

    update_population_window_title(fig);

    drawnow;

    %==============================================================
    % WAIT
    %==============================================================

    uiwait(fig);

    %==============================================================
    % SELECTED SIGNAL
    %==============================================================

    if ishghandle(fig) && ...
            isappdata(fig,'selected_signal')

        selected_signal = ...
            char( ...
                string( ...
                    getappdata(fig,'selected_signal')));
    end

    %==============================================================
    % REPROCESS
    %==============================================================

    has_new_outputs = false;

    if ishghandle(fig) && ...
            isappdata(fig,'request_reprocess')

        request_reprocess = ...
            logical( ...
                getappdata( ...
                    fig, ...
                    'request_reprocess'));
    end

    %==============================================================
    % OUTPUTS
    %==============================================================

    if ishghandle(fig) && ...
            isappdata(fig,'last_save_outputs')

        out = ...
            getappdata(fig,'last_save_outputs');

        has_new_outputs = true;

        valid_cells = ...
            out.valid_cells;

        DF_raw = ...
            out.DF_raw;

        DF_sg = ...
            out.DF_sg;

        F0 = ...
            out.F0;

        noise_est = ...
            out.noise_est;

        Raster = ...
            out.Raster;

        Acttmp2 = ...
            out.Acttmp2;

        MAct = ...
            out.MAct;

        thresholds = ...
            out.thresholds;

    else

        Raster = ...
            false(size(F));

        Acttmp2 = ...
            repmat( ...
                {[]}, ...
                nCells, ...
                1);

        MAct = [];

        thresholds = ...
            nan(nCells,1);

        valid_cells = [];

        DF_sg = [];
        DF_raw = [];
        F0 = [];
        noise_est = [];
    end

    if ishghandle(fig)
        delete(fig);
    end
end

%% ===================== POPULATION =====================

function indices = ...
        normalize_electroporated_indices( ...
            indices, ...
            nCells)

    if nargin < 2 || ...
            isempty(nCells) || ...
            ~isfinite(nCells)

        nCells = 0;
    end

    if isempty(indices)

        indices = ...
            zeros(0,1);

        return;
    end

    indices = ...
        round( ...
            double(indices(:)));

    indices = ...
        indices( ...
            isfinite(indices) & ...
            indices >= 1 & ...
            indices <= nCells);

    indices = ...
        unique( ...
            indices, ...
            'stable');
end


function indices = ...
        get_active_population_indices( ...
            fig, ...
            nCells)

    all_indices = ...
        (1:nCells).';

    selected_signal = ...
        'combined';

    if isappdata(fig,'selected_signal')

        selected_signal = ...
            lower( ...
                char( ...
                    string( ...
                        getappdata( ...
                            fig, ...
                            'selected_signal'))));
    end

    electroporated_indices = [];

    if isappdata(fig,'electroporated_indices')

        electroporated_indices = ...
            getappdata( ...
                fig, ...
                'electroporated_indices');
    end

    electroporated_indices = ...
        normalize_electroporated_indices( ...
            electroporated_indices, ...
            nCells);

    switch selected_signal

        case 'combined'

            indices = ...
                all_indices;

        case 'electroporated'

            indices = ...
                electroporated_indices;

        case 'gcamp'

            indices = ...
                setdiff( ...
                    all_indices, ...
                    electroporated_indices, ...
                    'stable');

        otherwise

            indices = ...
                all_indices;
    end
end


function select_population_checkbox( ...
        fig, ...
        src, ...
        selected_signal)

    if ~ishghandle(fig)
        return;
    end

    % Impossible d'avoir zéro case cochée.
    if get(src,'Value') == 0

        set(src,'Value',1);
        return;
    end

    tags = { ...
        'cb_population_gcamp', ...
        'cb_population_electroporated', ...
        'cb_population_combined'};

    for k = 1:numel(tags)

        h = ...
            findobj( ...
                fig, ...
                'Tag', ...
                tags{k});

        if isempty(h)
            continue;
        end

        if h ~= src

            set( ...
                h, ...
                'Value', ...
                0);
        end
    end

    %==========================================================
    % SEULEMENT changement d'affichage.
    %
    % manual_status et cutoff_status NE SONT PAS touchés.
    %
    % C'est ce qui assure la propagation :
    %
    % combined <-> GCaMP <-> Electroporated
    %==========================================================

    setappdata( ...
        fig, ...
        'selected_signal', ...
        selected_signal);
    
    update_population_action_buttons(fig);

    update_population_window_title(fig);

    refresh_selection_order(fig);

    if isappdata(fig,'order_cells')

        order_cells = ...
            getappdata(fig,'order_cells');

        if ~isempty(order_cells)

            update_current_cell( ...
                fig, ...
                1);

        else

            update_peak_histogram(fig);
        end
    end

    drawnow;
end


function update_population_window_title(fig)

    selected_signal = ...
        'combined';

    if isappdata(fig,'selected_signal')

        selected_signal = ...
            char( ...
                string( ...
                    getappdata( ...
                        fig, ...
                        'selected_signal')));
    end

    title_parts = {};

    if isappdata(fig,'viewer_mode') && ...
            getappdata(fig,'viewer_mode')

        title_parts{end+1} = ...
            '[VIEWER MODE]';
    end

    title_parts{end+1} = ...
        upper(selected_signal);

    if isappdata(fig,'gcamp_output_folder')

        folder = ...
            getappdata( ...
                fig, ...
                'gcamp_output_folder');

        if ~isempty(folder)

            title_parts{end+1} = ...
                char(string(folder));
        end
    end

    if isappdata(fig,'F_raw')

        F = ...
            getappdata( ...
                fig, ...
                'F_raw');

        active_indices = ...
            get_active_population_indices( ...
                fig, ...
                size(F,1));

        title_parts{end+1} = ...
            sprintf( ...
                'nCells=%d', ...
                numel(active_indices));
    end

    set( ...
        fig, ...
        'Name', ...
        strjoin( ...
            title_parts, ...
            ' | '));
end


function value = on_off(tf)

    if tf

        value = 'on';

    else

        value = 'off';
    end
end

function effective_status = ...
        get_effective_cell_status(fig)

    manual_status = [];

    cutoff_status = [];

    if isappdata(fig,'manual_status')

        manual_status = ...
            getappdata( ...
                fig, ...
                'manual_status');
    end

    if isappdata(fig,'cutoff_status')

        cutoff_status = ...
            getappdata( ...
                fig, ...
                'cutoff_status');
    end

    nCells = ...
        max( ...
            numel(manual_status), ...
            numel(cutoff_status));

    if nCells == 0

        effective_status = ...
            zeros(0,1);

        return;
    end

    if numel(manual_status) ~= nCells

        manual_status = ...
            zeros(nCells,1);
    end

    if numel(cutoff_status) ~= nCells

        cutoff_status = ...
            zeros(nCells,1);
    end

    % Cutoff par défaut
    effective_status = ...
        cutoff_status(:);

    % Décision manuelle PRIORITAIRE
    manual_defined = ...
        manual_status ~= 0;

    effective_status(manual_defined) = ...
        manual_status(manual_defined);
end

%% ===================== DETECTION PIPELINE =====================

function opts = convert_opts_ms_to_frames(opts, fs)

    if nargin < 2 || isempty(fs) || ~isfinite(fs) || fs <= 0
        error('convert_opts_ms_to_frames: fs invalide.');
    end

    opts.window_size  = max(1, round(opts.window_size_s * fs));
    opts.refrac_fr    = max(1, round(opts.refrac_ms * fs / 1000));

    % SavGol maintenant normalisé au framerate par plan
    sg = round(opts.savgol_win_ms * fs / 1000);

    % doit être impair et suffisamment grand pour le polynôme
    sg = max(opts.savgol_poly + 2, sg);

    if mod(sg,2) == 0
        sg = sg + 1;
    end

    opts.savgol_win = sg;
end

function DF_sg = savgol_transform(DF, opts)

    sg_win  = opts.savgol_win;
    sg_poly = opts.savgol_poly;

    [NCell, Nz] = size(DF);

    DF_sg = nan(NCell, Nz);

    sgN = max(sg_poly + 2, round(sg_win));
    if mod(sgN,2) == 0
        sgN = sgN + 1;
    end
    if sgN > Nz
        sgN = Nz - (mod(Nz,2) == 0);
    end
    if sgN <= sg_poly
        sgN = sg_poly + 2;
        if mod(sgN,2) == 0
            sgN = sgN + 1;
        end
        if sgN > Nz
            sgN = Nz - (mod(Nz,2) == 0);
        end
    end

    for n = 1:NCell
        sig = DF(n,:);

        if sum(isfinite(sig)) >= sgN
            try
                DF_sg(n,:) = sgolayfilt(sig, sg_poly, sgN);
            catch
                DF_sg(n,:) = sig;
            end
        end
    end
end

function out = detect_peaks_cell_core(x, sigma, opts, bad_frames)

    if nargin < 4
        bad_frames = [];
    end

    out = struct( ...
        'threshold', NaN, ...
        'bad_mask', [], ...
        'locs_raw', []);

    if isempty(x)
        return;
    end

    x = x(:);
    Nx = numel(x);

    if all(~isfinite(x))
        return;
    end

    bad_mask = make_bad_mask(bad_frames, Nx);
    out.bad_mask = bad_mask;

    %seuil_detection = 2.33 * sigma;
    seuil_detection= 3.09 * sigma ;

    if ~isfinite(seuil_detection) || seuil_detection <= 0
        seuil_detection = 0;
    end
    out.threshold = seuil_detection;

    prom = seuil_detection * opts.prominence_factor;

    if ~isfinite(prom) || prom < 0
        prom = 0;
    end

    valid_mask = isfinite(x) & ~bad_mask;

    if ~any(valid_mask)
        return;
    end

    if max(x(valid_mask)) <= seuil_detection
        return;
    end

    % Découpe en segments continus valides
    d = diff([false; valid_mask; false]);
    seg_start = find(d == 1);
    seg_end   = find(d == -1) - 1;

    locs_all = [];

    for s = 1:numel(seg_start)

        idx = seg_start(s):seg_end(s);
        x_seg = x(idx);

        if numel(x_seg) < 3
            continue;
        end

        if max(x_seg) <= seuil_detection
            continue;
        end
        
        mpd = max(1, round(opts.refrac_fr));
        
        warnState = warning('off','signal:findpeaks:largeMinPeakHeight');
    
        try
            max_signal = max(x_seg, [], 'omitnan');
        
            if isempty(max_signal) || ...
               ~isfinite(max_signal) || ...
               max_signal <= seuil_detection
        
                locs_seg = [];
        
            else
                [~, locs_seg] = findpeaks(x_seg, ...
                    'MinPeakHeight', seuil_detection, ...
                    'MinPeakProminence', prom, ...
                    'MinPeakDistance', mpd);
            end
        
        catch
            locs_seg = [];
        end
    
        warning(warnState);

        if ~isempty(locs_seg)
            locs_all = [locs_all; idx(locs_seg(:))']; %#ok<AGROW>
        end
    end

    if isempty(locs_all)
        return;
    end

    locs_all = unique(locs_all(:));
    locs_all = locs_all(locs_all >= 1 & locs_all <= Nx);
    locs_all = locs_all(~bad_mask(locs_all));

    out.locs_raw = locs_all;
end

function [A, SNR, score, cells_sorted_by_quality, quality_min, quality_max, quality_thr0] = ...
    compute_snr_quality(DF, noise_est, opts, bad_frames)

    if nargin < 3 || isempty(opts)
        error('compute_snr_quality requires DF, noise_est, and opts.');
    end

    if nargin < 4
        bad_frames = [];
    end

    if isempty(DF) || ndims(DF) ~= 2
        error('DF must be a 2D matrix [NCell x Nz].');
    end

    [NCell, ~] = size(DF);

    noise_est = noise_est(:);

    if numel(noise_est) ~= NCell
        error('noise_est must have one value per cell (%d expected).', NCell);
    end

    noise_est(~isfinite(noise_est) | noise_est <= 0) = eps;

    A     = zeros(NCell,1);
    SNR   = zeros(NCell,1);
    score = zeros(NCell,1);

    for cid = 1:NCell

        x_detect = DF(cid,:).';
        sigma = noise_est(cid);

        if isempty(x_detect) || all(~isfinite(x_detect))
            continue;
        end

        out = detect_peaks_cell_core(x_detect, sigma, opts, bad_frames);

        if isempty(out.locs_raw)
            continue;
        end

        peak_vals = x_detect(out.locs_raw);
        peak_vals = peak_vals(isfinite(peak_vals));

        if isempty(peak_vals)
            continue;
        end

        A(cid) = median(peak_vals);

        if ~isfinite(A(cid)) || A(cid) < 0
            A(cid) = 0;
        end

        SNR(cid) = A(cid) / sigma;

        if ~isfinite(SNR(cid)) || SNR(cid) < 0
            SNR(cid) = 0;
        end

        n_peaks = numel(out.locs_raw);        

        score(cid) = SNR(cid) .* log1p(n_peaks);

        if ~isfinite(score(cid)) || score(cid) < 0
            score(cid) = 0;
        end
    end

    [~, cells_sorted_by_quality] = sort(score, 'ascend');
    cells_sorted_by_quality = cells_sorted_by_quality(:);

    quality_min  = double(1);
    quality_max  = double(NCell);
    quality_thr0 = double(max(1, round(0.5 * NCell)));
end

function noise_est = estimate_noise(DF)

    [NCell, ~] = size(DF);
    noise_est = nan(NCell, 1);

    for n = 1:NCell
        d = diff(DF(n,:));
        d = d(isfinite(d));

        if ~isempty(d)
            ne = 1.4826 * mad(d, 1) / sqrt(2);
        else
            ne = NaN;
        end

        if ~isfinite(ne) || ne <= 0
            ne = std(DF(n,:), 'omitnan');
        end
        if ~isfinite(ne) || ne <= 0
            ne = eps;
        end

        noise_est(n) = ne;
    end
end

function bad_mask = make_bad_mask(bad_frames, Nx)

    bad_mask = false(Nx,1);

    if isempty(bad_frames)
        return;
    end

    if islogical(bad_frames)
        bf = bad_frames(:);
        L = min(Nx, numel(bf));
        bad_mask(1:L) = bf(1:L);
    else
        bad_idx = round(bad_frames(:));
        bad_idx = bad_idx(isfinite(bad_idx) & bad_idx >= 1 & bad_idx <= Nx);
        bad_mask(bad_idx) = true;
    end
end

%% ===================== PEAK DETECTION AND SAVE =====================
function auto_detect_and_add(fig)

    if ~isappdata(fig,'DF_sg') || ~isappdata(fig,'cell_id')
        return;
    end

    DF  = getappdata(fig,'DF_sg');
    cid = getappdata(fig,'cell_id');

    if isempty(cid) || ~isscalar(cid) || ~isfinite(cid)
        return;
    end

    cid = round(cid);

    if cid < 1 || cid > size(DF,1)
        return;
    end

    viewer_mode = isappdata(fig,'viewer_mode') && getappdata(fig,'viewer_mode');

    % =====================================================
    % VIEWER MODE : uniquement pics/seuils sauvegardés
    % =====================================================
    if viewer_mode

        auto_peaks = [];
        seuil = NaN;

        if isappdata(fig,'Acttmp2_saved')
            Acttmp2_saved = getappdata(fig,'Acttmp2_saved');

            if iscell(Acttmp2_saved) && cid <= numel(Acttmp2_saved)
                auto_peaks = Acttmp2_saved{cid};
            end
        end

        if isempty(auto_peaks) && isappdata(fig,'Raster_saved')
            Raster_saved = getappdata(fig,'Raster_saved');

            if ~isempty(Raster_saved) && cid <= size(Raster_saved,1)
                auto_peaks = find(Raster_saved(cid,:));
            end
        end

        if isappdata(fig,'thresholds_saved')
            thresholds_saved = getappdata(fig,'thresholds_saved');

            if ~isempty(thresholds_saved) && cid <= numel(thresholds_saved)
                seuil = thresholds_saved(cid);
            end
        end

        setappdata(fig,'auto_peaks', auto_peaks);
        setappdata(fig,'seuil_detection_last', seuil);

        refresh_data(fig);
        return;
    end

    % =====================================================
    % MODE NORMAL : détection active
    % =====================================================
    if ~isappdata(fig,'opts') || ~isappdata(fig,'noise_est')
        return;
    end

    opts      = getappdata(fig,'opts');
    noise_est = getappdata(fig,'noise_est');

    if isappdata(fig,'bad_frames')
        bad_frames = getappdata(fig,'bad_frames');
    else
        bad_frames = [];
    end

    x = DF(cid,:).';
    sigma = noise_est(cid);

    if ~isfinite(sigma) || sigma <= 0
        sigma = std(x,'omitnan');
    end
    if ~isfinite(sigma) || sigma <= 0
        sigma = eps;
    end

    out = detect_peaks_cell_core(x, sigma, opts, bad_frames);

    setappdata(fig,'auto_peaks', out.locs_raw);
    setappdata(fig,'seuil_detection_last', out.threshold);

    refresh_data(fig);
end

function recompute_n_peaks_all(fig)
    DF     = getappdata(fig,'DF_sg');
    noise_est = getappdata(fig,'noise_est');
    opts      = getappdata(fig,'opts');

    nCells = size(DF,1);
    n_peaks_all = zeros(nCells,1);

    if isappdata(fig,'bad_frames')
        bad_frames = getappdata(fig,'bad_frames');
    else
        bad_frames = [];
    end

    for cid = 1:nCells
        x = DF(cid,:).';
        sigma = noise_est(cid);

        if ~isfinite(sigma) || sigma <= 0
            sigma = std(x,'omitnan');
        end
        if ~isfinite(sigma) || sigma <= 0
            sigma = eps;
        end

        out = detect_peaks_cell_core(x, sigma, opts, bad_frames);
        n_peaks_all(cid) = numel(out.locs_raw);
    end

    setappdata(fig,'n_peaks_all', n_peaks_all);
end

function [invalid_cells, valid_cells, DF, F0, noise_est, ...
          Raster, Acttmp2, MAct, thresholds, opts, summary] = ...
    save_peak_matrix(fig, synchronous_frames)

    DF = ...
        getappdata(fig,'DF_sg');

    F0 = ...
        getappdata(fig,'F0');

    opts = ...
        getappdata(fig,'opts');

    noise_est = ...
        getappdata(fig,'noise_est');

    if isappdata(fig,'bad_frames')

        bad_frames = ...
            getappdata(fig,'bad_frames');

    else

        bad_frames = [];
    end

    nCells = ...
        size(DF,1);

    Nz = ...
        size(DF,2);

    %==============================================================
    % Population active = indices Combined
    %==============================================================

    active_indices = ...
        get_active_population_indices( ...
            fig, ...
            nCells);

    %==============================================================
    % État global
    %==============================================================

    manual_status = ...
        getappdata( ...
            fig, ...
            'manual_status');

    cutoff_status = ...
        getappdata( ...
            fig, ...
            'cutoff_status');

    effective_status = ...
        get_effective_cell_status(fig);

    cutoff_validated = ...
        isappdata(fig,'cutoff_validated') && ...
        getappdata(fig,'cutoff_validated');

    % ==============================================================
    % Population autorisée par les décisions globales
    %
    % -1 = rejetée
    %  0 = pas encore soumise au cutoff
    % +1 = retenue
    % ==============================================================
    
    candidate_keep = ...
        effective_status ~= -1;
    
    % ==============================================================
    % Exclusion automatique des cellules sans pic
    %
    % Exception :
    % une cellule explicitement gardée manuellement reste autorisée.
    % ==============================================================
    
    n_peaks_all = ...
        getappdata(fig,'n_peaks_all');
    
    has_peaks = ...
        n_peaks_all > 0;
    
    manual_keep = ...
        manual_status == +1;
    
    candidate_keep = ...
        candidate_keep & ...
        (has_peaks | manual_keep);
   
    %==============================================================
    % Matrices globales Combined
    %==============================================================

    Raster_all = ...
        false(nCells,Nz);

    Acttmp2_all = ...
        cell(nCells,1);

    thresholds_all = ...
        nan(nCells,1);

    keep_mask = ...
        false(nCells,1);

    %==============================================================
    % Détection uniquement cellules de population active retenues
    %==============================================================

    candidate_indices = ...
        find(candidate_keep);

    for cid = ...
            candidate_indices(:).'

        x = ...
            DF(cid,:).';

        if isempty(x) || ...
                all(~isfinite(x))

            continue;
        end

        sigma = ...
            noise_est(cid);

        if ~isfinite(sigma) || ...
                sigma <= 0

            sigma = ...
                std(x,'omitnan');
        end

        if ~isfinite(sigma) || ...
                sigma <= 0

            sigma = eps;
        end

        out = ...
            detect_peaks_cell_core( ...
                x, ...
                sigma, ...
                opts, ...
                bad_frames);

        Acttmp2_all{cid} = ...
            out.locs_raw;

        thresholds_all(cid) = ...
            out.threshold;

        if ~isempty(out.locs_raw)

            Raster_all( ...
                cid, ...
                out.locs_raw) = true;
        
            keep_mask(cid) = true;
        
        elseif manual_status(cid) == +1
        
            % Autoriser explicitement une cellule sans pic
            % si l'utilisateur a demandé de la conserver.
            keep_mask(cid) = true;
        end
    end

    %==============================================================
    % Indices retenus en référentiel Combined
    %==============================================================

    valid_combined_cells = ...
        find(keep_mask);

    %==============================================================
    % Conversion vers indices LOCAUX de la population sélectionnée
    %
    % Ex :
    % electroporated Combined 101:120
    %
    % Combined 103 -> electroporated local 3
    %==============================================================

    valid_cells = ...
    valid_combined_cells(:);

    invalid_cells = ...
        ~keep_mask;

    valid_cells = ...
        valid_cells(:);

    %==============================================================
    % OUTPUT MATRICES
    %==============================================================

    DF = ...
        DF(valid_combined_cells,:);

    F0 = ...
        F0(valid_combined_cells,:);

    noise_est = ...
        noise_est(valid_combined_cells);

    Raster = ...
        Raster_all(valid_combined_cells,:);

    Acttmp2 = ...
        Acttmp2_all(valid_combined_cells);

    thresholds = ...
        thresholds_all(valid_combined_cells);

    %==============================================================
    % MAct
    %==============================================================

    if Nz > synchronous_frames

        MAct = ...
            zeros( ...
                1, ...
                Nz - synchronous_frames);

        for i = 1:(Nz - synchronous_frames)

            MAct(i) = ...
                sum( ...
                    max( ...
                        Raster(:, ...
                            i:i+synchronous_frames), ...
                        [], ...
                        2));
        end

    else

        MAct = ...
            zeros(1,0);
    end

    %==============================================================
    % SUMMARY
    %==============================================================

    electroporated_indices = ...
        getappdata( ...
            fig, ...
            'electroporated_indices');

    electroporated_indices = ...
        normalize_electroporated_indices( ...
            electroporated_indices, ...
            nCells);

    gcamp_indices = ...
        setdiff( ...
            (1:nCells).', ...
            electroporated_indices, ...
            'stable');

    selected_signal = ...
        char( ...
            string( ...
                getappdata(fig,'selected_signal')));

    summary = struct();

    summary.selected_signal = ...
        selected_signal;

    summary.active_combined_indices = ...
        active_indices(:);

    summary.valid_combined_cells = ...
        valid_combined_cells(:);

    summary.valid_local_cells = ...
        valid_cells(:);

    summary.gcamp_combined_indices = ...
        gcamp_indices(:);

    summary.electroporated_combined_indices = ...
        electroporated_indices(:);

    summary.manual_status = ...
        manual_status(:);

    summary.cutoff_status = ...
        cutoff_status(:);

    summary.effective_status = ...
        effective_status(:);

    valid_active_cells = ...
    intersect( ...
        valid_combined_cells, ...
        active_indices, ...
        'stable');

    summary.n_total = ...
        numel(active_indices);
    
    summary.n_kept_final = ...
        numel(valid_active_cells);
    
    summary.n_kept_combined_final = ...
        numel(valid_combined_cells);

    summary.n_manual_keep = ...
        sum( ...
            manual_status(active_indices) == +1);

    summary.n_manual_excl = ...
        sum( ...
            manual_status(active_indices) == -1);

    summary.n_cutoff_keep = ...
        sum( ...
            cutoff_status(active_indices) == +1);

    summary.n_cutoff_excl = ...
        sum( ...
            cutoff_status(active_indices) == -1);

    % fprintf('\n');
    % fprintf( ...
    %     '=> %s : %d cellules conservées sur %d (%.1f%%)\n', ...
    %     upper(selected_signal), ...
    %     numel(valid_active_cells), ...
    %     numel(active_indices), ...
    %     100 * numel(valid_active_cells) / ...
    %     max(1,numel(active_indices)));
    % 
    % fprintf( ...
    %     '=> COMBINED final : %d / %d cellules conservées\n', ...
    %     numel(valid_combined_cells), ...
    %     nCells);
end

%% ===================== NAVIGATION AND CUTOFF =====================

function update_current_cell(fig, idx_slider)

    if ~isappdata(fig,'order_cells')
        return;
    end

    order_cells = getappdata(fig,'order_cells');
    if isempty(order_cells)
        return;
    end

    idx = round(idx_slider);
    idx = max(1, min(numel(order_cells), idx));

    cid = order_cells(idx);

    setappdata(fig,'current_rank', idx);
    setappdata(fig,'nav_rank', idx);
    setappdata(fig,'cell_id', cid);

    sldr = findobj(fig,'Tag','sldr_nav_cell');
    if ~isempty(sldr) && isgraphics(sldr)
        set(sldr,'Min',1,'Max',numel(order_cells),'Value',idx);
        step = 1/max(1,numel(order_cells)-1);
        set(sldr,'SliderStep',[step min(1,10*step)]);
    end

    lbl = findobj(fig,'Tag','lbl_nav_cell');
    if ~isempty(lbl)
        lbl.String = sprintf('Navigation cellule (%d / %d)', idx, numel(order_cells));
    end

    setappdata(fig,'autotervals', []);
    if isappdata(fig,'seuil_detection_last')
        rmappdata(fig,'seuil_detection_last');
    end

    auto_detect_and_add(fig);
end

function next_cell(fig)

    if ~isappdata(fig,'current_rank')
        idx = 1;
    else
        idx = getappdata(fig,'current_rank');
    end

    if ~isappdata(fig,'order_cells')
        return;
    end
    order_cells = getappdata(fig,'order_cells');
    if isempty(order_cells)
        return;
    end

    idx = min(idx + 1, numel(order_cells));
    update_current_cell(fig, idx);
end

function prev_cell(fig)

    if ~isappdata(fig,'current_rank')
        idx = 1;
    else
        idx = getappdata(fig,'current_rank');
    end

    if ~isappdata(fig,'order_cells')
        return;
    end
    order_cells = getappdata(fig,'order_cells');
    if isempty(order_cells)
        return;
    end

    idx = max(idx - 1, 1);
    update_current_cell(fig, idx);
end

function goto_navigationdex(fig, hEdit)

    if ~isappdata(fig,'order_cells')
        return;
    end

    order_cells = getappdata(fig,'order_cells');
    if isempty(order_cells)
        return;
    end

    if numel(hEdit) > 1
        hEdit = hEdit(1);
    end
    if isempty(hEdit) || ~isgraphics(hEdit)
        return;
    end

    txt = get(hEdit, 'String');
    idx = str2double(txt);

    if ~isfinite(idx)
        idx = 1;
    end

    idx = round(idx);
    idx = max(1, min(numel(order_cells), idx));

    setappdata(fig,'nav_rank', idx);

    viewer_mode = isappdata(fig,'viewer_mode') && getappdata(fig,'viewer_mode');
    locked = isappdata(fig,'cutoff_locked') && getappdata(fig,'cutoff_locked');

    if ~viewer_mode && ~locked
        setappdata(fig,'cutoff_rank', idx);
    end

    set(hEdit, 'String', num2str(idx));
    update_current_cell(fig, idx);
end

%% ===================== CUTOFF =====================

function apply_auto_cutoff(fig)

    if ~ishghandle(fig)
        return;
    end

    if isappdata(fig,'viewer_mode') && ...
            getappdata(fig,'viewer_mode')

        return;
    end

    if ~isappdata(fig,'n_peaks_all') || ...
            ~isappdata(fig,'opts')

        return;
    end

    n_peaks_all = ...
        getappdata( ...
            fig, ...
            'n_peaks_all');

    opts = ...
        getappdata( ...
            fig, ...
            'opts');

    if isempty(n_peaks_all)
        return;
    end

    nCells = ...
        numel(n_peaks_all);

    active_indices = ...
        get_active_population_indices( ...
            fig, ...
            nCells);

    if isempty(active_indices)
        return;
    end

    %==========================================================
    % Peaks
    %==========================================================

    good_by_peaks = ...
        n_peaks_all >= ...
        opts.min_n_peaks_cutoff;

    %==========================================================
    % Mask size
    %==========================================================

    mask_sizes = [];

    if isappdata(fig,'mask_sizes')

        mask_sizes = ...
            getappdata( ...
                fig, ...
                'mask_sizes');
    end

    if ~isempty(mask_sizes) && ...
            numel(mask_sizes) == nCells

        good_by_mask = ...
            mask_sizes >= ...
            opts.min_mask_um2;

    else

        good_by_mask = ...
            true(nCells,1);
    end

    %==========================================================
    % Connectivity
    %==========================================================

    mask_connectivity_ratio = [];

    if isappdata(fig,'mask_connectivity_ratio')

        mask_connectivity_ratio = ...
            getappdata( ...
                fig, ...
                'mask_connectivity_ratio');
    end

    if ~isempty(mask_connectivity_ratio) && ...
            numel(mask_connectivity_ratio) == nCells

        good_by_connectivity = ...
            mask_connectivity_ratio >= ...
            opts.min_mask_connectivity;

    else

        good_by_connectivity = ...
            true(nCells,1);
    end

    cutoff_good = ...
        good_by_peaks & ...
        good_by_mask & ...
        good_by_connectivity;

    %==========================================================
    % cutoff_status GLOBAL
    %
    % On modifie UNIQUEMENT la population actuellement affichée.
    %
    % Mais puisque les indices sont Combined, le résultat est
    % immédiatement visible dans les autres vues.
    %==========================================================

    cutoff_status = ...
        getappdata( ...
            fig, ...
            'cutoff_status');

    if isempty(cutoff_status) || ...
            numel(cutoff_status) ~= nCells

        cutoff_status = ...
            zeros(nCells,1);
    end

    cutoff_status(active_indices) = -1;

    cutoff_status( ...
        active_indices( ...
            cutoff_good(active_indices))) = +1;

    setappdata( ...
        fig, ...
        'cutoff_status', ...
        cutoff_status);

    setappdata( ...
        fig, ...
        'cutoff_validated', ...
        true);

    setappdata( ...
        fig, ...
        'cutoff_locked', ...
        true);

    selected_cells_from_cutoff = ...
        active_indices( ...
            cutoff_status(active_indices) == +1);

    setappdata( ...
        fig, ...
        'selected_cells_from_cutoff', ...
        selected_cells_from_cutoff(:));

    selected_signal = ...
        char( ...
            string( ...
                getappdata( ...
                    fig, ...
                    'selected_signal')));

    fprintf('\n');
    fprintf( ...
        'Cutoff appliqué à %s\n', ...
        upper(selected_signal));

    fprintf( ...
        '  Total        : %d\n', ...
        numel(active_indices));

    fprintf( ...
        '  Conservées   : %d\n', ...
        sum( ...
            cutoff_status(active_indices) == +1));

    fprintf( ...
        '  Exclues      : %d\n', ...
        sum( ...
            cutoff_status(active_indices) == -1));

    fprintf( ...
        '  Peaks        : >= %d\n', ...
        opts.min_n_peaks_cutoff);

    fprintf( ...
        '  Mask         : >= %.1f um²\n', ...
        opts.min_mask_um2);

    fprintf( ...
        '  Connectivity : >= %.2f\n', ...
        opts.min_mask_connectivity);

    refresh_selection_order(fig);
end


function validate_selection_filter(fig)

    if ~ishghandle(fig)
        return;
    end

    if isappdata(fig,'viewer_mode') && ...
            getappdata(fig,'viewer_mode')

        return;
    end

    apply_auto_cutoff(fig);

    if isappdata(fig,'order_cells')

        order_cells = ...
            getappdata( ...
                fig, ...
                'order_cells');

        fprintf( ...
            'Population affichée après cutoff : %d cellules\n', ...
            numel(order_cells));
    end
end

function refresh_selection_order(fig)

    if ~isappdata(fig,'cells_sorted_by_quality')

        update_empty_navigation(fig);
        return;
    end

    cells_sorted_by_quality = ...
        getappdata( ...
            fig, ...
            'cells_sorted_by_quality');

    if isempty(cells_sorted_by_quality)

        update_empty_navigation(fig);
        return;
    end

    nCells = ...
        numel(cells_sorted_by_quality);

    %==========================================================
    % Population active
    %==========================================================

    active_indices = ...
        get_active_population_indices( ...
            fig, ...
            nCells);

    order_cells_all = ...
        cells_sorted_by_quality( ...
            ismember( ...
                cells_sorted_by_quality, ...
                active_indices));

    %==========================================================
    % Retirer les cellules à 0 pics
    %==========================================================

    if isappdata(fig,'n_peaks_all')

        n_peaks_all = ...
            getappdata( ...
                fig, ...
                'n_peaks_all');

        valid_idx = ...
            order_cells_all >= 1 & ...
            order_cells_all <= numel(n_peaks_all);

        order_cells_all = ...
            order_cells_all(valid_idx);

        order_cells_all = ...
            order_cells_all( ...
                n_peaks_all(order_cells_all) > 0);
    end

    setappdata( ...
        fig, ...
        'order_cells_all', ...
        order_cells_all);

    if isempty(order_cells_all)

        update_empty_navigation(fig);
        return;
    end

    %==========================================================
    % État GLOBAL Combined
    %==========================================================

    effective_status = ...
        get_effective_cell_status(fig);

    % ==========================================================
    % -1 = exclue
    %  0 = pas encore évaluée -> reste visible
    % +1 = conservée
    %
    % manual_status est déjà prioritaire via
    % get_effective_cell_status().
    % ==========================================================
    order_cells = ...
        order_cells_all( ...
            effective_status(order_cells_all) ~= -1);
    
        setappdata( ...
            fig, ...
            'order_cells', ...
            order_cells);
    
        if isempty(order_cells)
    
            update_empty_navigation(fig);
            return;
        end

    %==========================================================
    % Conserver cellule courante si possible
    %==========================================================

    old_cid = [];

    if isappdata(fig,'cell_id')

        old_cid = ...
            getappdata( ...
                fig, ...
                'cell_id');
    end

    idx = 1;

    if ~isempty(old_cid)

        k = ...
            find( ...
                order_cells == old_cid, ...
                1);

        if ~isempty(k)
            idx = k;
        end
    end

    idx = ...
        max( ...
            1, ...
            min( ...
                numel(order_cells), ...
                idx));

    setappdata(fig,'current_rank',idx);
    setappdata(fig,'nav_rank',idx);
    setappdata(fig,'cell_id',order_cells(idx));

    %==========================================================
    % Slider
    %==========================================================

    sldr = ...
        findobj( ...
            fig, ...
            'Tag', ...
            'sldr_nav_cell');

    if ~isempty(sldr) && ...
            isgraphics(sldr)

        n = ...
            numel(order_cells);

        step = ...
            1 / ...
            max(1,n-1);

        set( ...
            sldr, ...
            'Min',1, ...
            'Max',max(1,n), ...
            'Value',idx, ...
            'SliderStep', ...
            [step min(1,10*step)]);
    end

    lbl = ...
        findobj( ...
            fig, ...
            'Tag', ...
            'lbl_nav_cell');

    if ~isempty(lbl)

        lbl.String = ...
            sprintf( ...
                'Navigation cellule (%d / %d)', ...
                idx, ...
                numel(order_cells));
    end

    auto_detect_and_add(fig);
end


function update_empty_navigation(fig)

    setappdata(fig,'order_cells',[]);

    sldr = ...
        findobj( ...
            fig, ...
            'Tag', ...
            'sldr_nav_cell');

    if ~isempty(sldr) && ...
            isgraphics(sldr)

        set( ...
            sldr, ...
            'Min',1, ...
            'Max',1, ...
            'Value',1, ...
            'SliderStep',[1 1]);
    end

    lbl = ...
        findobj( ...
            fig, ...
            'Tag', ...
            'lbl_nav_cell');

    if ~isempty(lbl)

        lbl.String = ...
            'Navigation cellule (0 / 0)';
    end

    update_peak_histogram(fig);
end

function navigate_cells(fig, evnt)

    viewer_mode = isappdata(fig,'viewer_mode') && logical(getappdata(fig,'viewer_mode'));

    switch evnt.Key
        case 'rightarrow'
            next_cell(fig);

        case 'leftarrow'
            prev_cell(fig);

        case {'delete','backspace'}
            if ~viewer_mode
                exclude_cell(fig);
            end

        case {'return','space'}
            if ~viewer_mode
                keep_cell(fig);
            end
    end
end

%% ===================== MANUAL CELL SELECTION =====================

%% ===================== MANUAL SELECTION =====================

function keep_cell(fig)

    if isappdata(fig,'viewer_mode') && ...
            getappdata(fig,'viewer_mode')

        return;
    end

    if ~isappdata(fig,'cell_id') || ...
            ~isappdata(fig,'manual_status')

        return;
    end

    cid = ...
        round( ...
            getappdata( ...
                fig, ...
                'cell_id'));

    manual_status = ...
        getappdata( ...
            fig, ...
            'manual_status');

    if isempty(cid) || ...
            cid < 1 || ...
            cid > numel(manual_status)

        return;
    end

    %==========================================================
    % cid est TOUJOURS l'indice Combined.
    %==========================================================

    manual_status(cid) = +1;

    setappdata( ...
        fig, ...
        'manual_status', ...
        manual_status);

    refresh_selection_order(fig);

    drawnow;
end


function exclude_cell(fig)

    if isappdata(fig,'viewer_mode') && ...
            getappdata(fig,'viewer_mode')

        return;
    end

    if ~isappdata(fig,'cell_id') || ...
            ~isappdata(fig,'manual_status')

        return;
    end

    cid = ...
        round( ...
            getappdata( ...
                fig, ...
                'cell_id'));

    manual_status = ...
        getappdata( ...
            fig, ...
            'manual_status');

    if isempty(cid) || ...
            cid < 1 || ...
            cid > numel(manual_status)

        return;
    end

    %==========================================================
    % cid est TOUJOURS l'indice Combined.
    %==========================================================

    manual_status(cid) = -1;

    setappdata( ...
        fig, ...
        'manual_status', ...
        manual_status);

    refresh_selection_order(fig);

    drawnow;
end

function update_population_action_buttons(fig)

    if ~ishghandle(fig)
        return;
    end

    viewer_mode = ...
        isappdata(fig,'viewer_mode') && ...
        getappdata(fig,'viewer_mode');

    selected_signal = '';

    if isappdata(fig,'selected_signal')
        selected_signal = ...
            lower(char(string( ...
                getappdata(fig,'selected_signal'))));
    end

    btn_cutoff = ...
        findobj(fig,'Tag','btn_apply_cutoff');

    btn_confirm = ...
        findobj(fig,'Tag','btn_confirm_selection');

    % ==========================================================
    % VIEWER :
    % les deux restent toujours bloqués.
    % ==========================================================
    if viewer_mode

        if ~isempty(btn_cutoff)
            set(btn_cutoff,'Enable','off');
        end

        if ~isempty(btn_confirm)
            set(btn_confirm,'Enable','off');
        end

        return;
    end

    % ==========================================================
    % MODE NORMAL :
    %
    % - COMBINED disponible :
    %       cutoff + confirmation uniquement depuis COMBINED
    %
    % - GCaMP-only :
    %       GCaMP est la population maître
    %       -> cutoff + confirmation autorisés
    % ==========================================================
    cell_type = '';

    if isappdata(fig,'cell_type')
        cell_type = ...
            lower(char(string( ...
                getappdata(fig,'cell_type'))));
    end

    if strcmp(cell_type,'combined')

        allow_actions = ...
            strcmp(selected_signal,'combined');

    elseif strcmp(cell_type,'gcamp')

        allow_actions = ...
            strcmp(selected_signal,'gcamp');

    else

        allow_actions = false;
    end

    state = ...
        on_off(allow_actions);

    if ~isempty(btn_cutoff)
        set(btn_cutoff,'Enable',state);
    end

    if ~isempty(btn_confirm)
        set(btn_confirm,'Enable',state);
    end
end

function finalize_and_close( ...
        fig, ...
        synchronous_frames)

    viewer_mode = ...
        isappdata(fig,'viewer_mode') && ...
        getappdata(fig,'viewer_mode');

    %==============================================================
    % VIEWER
    %==============================================================
    if viewer_mode

        DF_raw = ...
            getappdata(fig,'DF_raw');

        DF_sg = ...
            getappdata(fig,'DF_sg');

        F0 = ...
            getappdata(fig,'F0');

        noise_est = ...
            getappdata(fig,'noise_est');

        Raster = ...
            getappdata(fig,'Raster_saved');

        Acttmp2 = ...
            getappdata(fig,'Acttmp2_saved');

        thresholds = ...
            getappdata(fig,'thresholds_saved');

        valid_cells = ...
            getappdata(fig,'valid_cells_saved');

        if isempty(valid_cells)

            valid_cells = ...
                (1:size(DF_sg,1)).';
        end

        % ----------------------------------------------------------
        % En Viewer on ne recalcule rien.
        % On retourne simplement les données déjà chargées.
        % ----------------------------------------------------------
        setappdata( ...
            fig, ...
            'last_save_outputs', ...
            struct( ...
                'invalid_cells', [], ...
                'valid_cells', valid_cells, ...
                'orig2new', [], ...
                'DF_sg', DF_sg, ...
                'DF_raw', DF_raw, ...
                'F0', F0, ...
                'noise_est', noise_est, ...
                'Raster', Raster, ...
                'Acttmp2', {Acttmp2}, ...
                'MAct', [], ...
                'thresholds', thresholds, ...
                'opts', [], ...
                'summary', []));

        if ishghandle(fig)
            uiresume(fig);
        end

        return;
    end

    %==============================================================
    % NORMAL MODE
    %==============================================================

    [ ...
        invalid_cells, ...
        valid_cells, ...
        DF, ...
        F0, ...
        noise_est, ...
        Raster, ...
        Acttmp2, ...
        MAct, ...
        thresholds, ...
        opts, ...
        summary ...
    ] = ...
        save_peak_matrix( ...
            fig, ...
            synchronous_frames);

    %==============================================================
    % Table selection
    %==============================================================
    try

        update_cell_selection_summary( ...
            fig, ...
            valid_cells, ...
            invalid_cells);

    catch ME

        warning( ...
            ['Impossible de mettre à jour le tableau ' ...
             'de sélection : %s'], ...
            ME.message);
    end

    %==============================================================
    % DF RAW sélectionné
    %==============================================================
    DF_raw_all = ...
        getappdata(fig,'DF_raw');

    if isfield(summary,'valid_combined_cells') && ...
            ~isempty(summary.valid_combined_cells) && ...
            ~isempty(DF_raw_all)

        DF_raw_selected = ...
            DF_raw_all( ...
                summary.valid_combined_cells, ...
                :);

    else

        DF_raw_selected = [];
    end

    %==============================================================
    % orig2new
    %
    % valid_cells = indices Combined originaux
    %==============================================================
    orig2new = ...
        nan( ...
            max( ...
                [valid_cells(:); 1]), ...
            1);

    if ~isempty(valid_cells)

        orig2new(valid_cells) = ...
            1:numel(valid_cells);
    end

    if iscell(Acttmp2) && ...
            size(Acttmp2,2) > 1

        Acttmp2 = ...
            reshape( ...
                Acttmp2, ...
                [], ...
                1);
    end

    %==============================================================
    % Save GUI outputs
    %==============================================================
    setappdata( ...
        fig, ...
        'last_save_outputs', ...
        struct( ...
            'invalid_cells', invalid_cells, ...
            'valid_cells', valid_cells, ...
            'orig2new', orig2new, ...
            'DF_sg', DF, ...
            'DF_raw', DF_raw_selected, ...
            'F0', F0, ...
            'noise_est', noise_est, ...
            'Raster', Raster, ...
            'Acttmp2', {Acttmp2}, ...
            'MAct', MAct, ...
            'thresholds', thresholds, ...
            'opts', opts, ...
            'summary', summary));

    if ishghandle(fig)
        uiresume(fig);
    end
end

%% ===================== GUI DISPLAY =====================
function refresh_data(fig)

    DF      = getappdata(fig,'DF_sg');
    F0      = getappdata(fig,'F0');
    cell_id = getappdata(fig,'cell_id');

    ax   = getappdata(fig,'ax1');
    axF0 = getappdata(fig,'axF0');

    hBad = [];
    if isappdata(fig,'hBadPatch_ax1')
        hBad = getappdata(fig,'hBadPatch_ax1');
    end

    kids = allchild(ax);
    if ~isempty(hBad) && isgraphics(hBad)
        delete(kids(kids ~= hBad));
    else
        delete(kids);
    end

    hBadF0 = [];
    if isappdata(fig,'hBadPatch_axF0')
        hBadF0 = getappdata(fig,'hBadPatch_axF0');
    end

    kidsF0 = allchild(axF0);
    if ~isempty(hBadF0) && isgraphics(hBadF0)
        delete(kidsF0(kidsF0 ~= hBadF0));
    else
        delete(kidsF0);
    end

    x = DF(cell_id,:);
    x = x(:).';

    T = numel(x);
    t = 1:T;

    xlim(ax,[1 max(1,T)]);
    plot(ax,t,x,'k-');
    hold(ax,'on');

    % ---- Stim frames ----
    if isappdata(fig,'stim_frames')

        stim_frames = getappdata(fig,'stim_frames');

        if ~isempty(stim_frames)

            stim_frames = round(stim_frames(:).');
            stim_frames = stim_frames(isfinite(stim_frames));
            stim_frames = stim_frames(stim_frames >= 1 & stim_frames <= T);

            if ~isempty(stim_frames)

                yl = ylim(ax);
                y_stim = yl(1) + 0.03 * diff(yl);

                plot(ax, ...
                    stim_frames, ...
                    repmat(y_stim, size(stim_frames)), ...
                    'v', ...
                    'LineStyle','none', ...
                    'MarkerSize',8, ...
                    'MarkerFaceColor',[0.45 0 0], ...
                    'MarkerEdgeColor',[0.20 0 0], ...
                    'LineWidth',1, ...
                    'Clipping','on');
            end
        end
    end

    % ---- Trace F0 ----
    if ~isempty(F0) && cell_id >= 1 && cell_id <= size(F0,1)
        f0 = F0(cell_id,:);
    else
        f0 = [];
    end

    if ~isempty(f0)

        f0 = f0(:).';

        L = min(numel(t), numel(f0));
        t_f0 = t(1:L);
        f0   = f0(1:L);

        xlim(axF0,[1 max(1,T)]);
        plot(axF0, t_f0, f0, 'b-');

        if ~isempty(hBadF0) && isgraphics(hBadF0) && isappdata(fig,'focus_segs')
            focus_segs = getappdata(fig,'focus_segs');
            update_badframe_patch(hBadF0, focus_segs, ylim(axF0));
            uistack(hBadF0,'bottom');
        end

        ylabel(axF0,'F0');

    else

        cla(axF0);
        text(axF0,0.5,0.5,'F0 indisponible', ...
            'Units','normalized', ...
            'HorizontalAlignment','center');
        set(axF0,'XTickLabel',[]);
    end

    if ~isempty(hBad) && isgraphics(hBad) && isappdata(fig,'focus_segs')
        focus_segs = getappdata(fig,'focus_segs');
        update_badframe_patch(hBad, focus_segs, ylim(ax));
        uistack(hBad,'bottom');
    end

    xlabel(ax,'Frames');
    ylabel(ax,'\DeltaF/F raw (SavGol)');

    % ---- Seuil ----
    if isappdata(fig,'seuil_detection_last')
        seuil_detection = getappdata(fig,'seuil_detection_last');

        if isfinite(seuil_detection)
            plot(ax,[1 max(1,T)],[seuil_detection seuil_detection],':', ...
                'Color',[.7 .1 .1], ...
                'LineWidth',1);
        end
    end

    % ---- Pics détectés ----
    if isappdata(fig,'auto_peaks')

        pk = getappdata(fig,'auto_peaks');
        pk = pk(:).';
        pk = pk(isfinite(pk) & pk >= 1 & pk <= T);

        if ~isempty(pk)
            plot(ax, pk, x(pk), '*', ...
                'Color', [0.85 0.1 0.1], ...
                'MarkerSize', 5, ...
                'LineWidth', 1);
        end
    end

    viewer_mode = isappdata(fig,'viewer_mode') && getappdata(fig,'viewer_mode');

    is_electroporated_cell = false;
    if isappdata(fig,'electroporated_indices')
        electroporated_indices = getappdata(fig,'electroporated_indices');

        if ~isempty(electroporated_indices)
            electroporated_indices = electroporated_indices(:);
            electroporated_indices = electroporated_indices(isfinite(electroporated_indices));
            is_electroporated_cell = any(round(electroporated_indices) == round(cell_id));
        end
    end

    if is_electroporated_cell
        text(ax, 0.72, 0.95, 'ÉLECTROPORÉE', ...
            'Units','normalized', ...
            'Color',[0.1 0.2 0.9], ...
            'FontWeight','bold', ...
            'FontSize',12, ...
            'VerticalAlignment','top', ...
            'BackgroundColor',[1 1 1 0.6], ...
            'Margin',4);
    end

    if ~viewer_mode
    
        label_txt   = '';
        label_color = [0 0 0];
    
        manual_status = ...
            getappdata(fig,'manual_status');
    
        cutoff_status = ...
            getappdata(fig,'cutoff_status');
    
        n_peaks_all = [];
    
        if isappdata(fig,'n_peaks_all')
            n_peaks_all = ...
                getappdata(fig,'n_peaks_all');
        end
    
        % ==========================================================
        % Décision manuelle prioritaire
        % ==========================================================
        if cell_id <= numel(manual_status) && ...
                manual_status(cell_id) == +1
    
            label_txt = ...
                'GOOD MANUEL';
    
            label_color = ...
                [0.1 0.6 0.1];
    
        elseif cell_id <= numel(manual_status) && ...
                manual_status(cell_id) == -1
    
            label_txt = ...
                'BAD MANUEL';
    
            label_color = ...
                [0.85 0.1 0.1];
    
        % ==========================================================
        % Cellule sans pic
        % ==========================================================
        elseif ~isempty(n_peaks_all) && ...
                cell_id <= numel(n_peaks_all) && ...
                n_peaks_all(cell_id) == 0
    
            label_txt = ...
                'AUTO BAD (0 pics)';
    
            label_color = ...
                [0.6 0.6 0.6];
    
        % ==========================================================
        % Résultat cutoff
        % ==========================================================
        elseif cell_id <= numel(cutoff_status) && ...
                cutoff_status(cell_id) == +1
    
            label_txt = ...
                'GOOD CUTOFF';
    
            label_color = ...
                [0.1 0.6 0.1];
    
        elseif cell_id <= numel(cutoff_status) && ...
                cutoff_status(cell_id) == -1
    
            label_txt = ...
                'BAD CUTOFF';
    
            label_color = ...
                [0.85 0.1 0.1];
        end
    
        if ~isempty(label_txt)
    
            text( ...
                ax, ...
                0.02, ...
                0.95, ...
                label_txt, ...
                'Units','normalized', ...
                'Color',label_color, ...
                'FontWeight','bold', ...
                'FontSize',12, ...
                'VerticalAlignment','top', ...
                'BackgroundColor',[1 1 1 0.6], ...
                'Margin',4);
        end
    end

    if isappdata(fig,'score_quality_percentile')

        q = getappdata(fig,'score_quality_percentile');
    
        if ~isempty(q) && cell_id <= numel(q) && isfinite(q(cell_id))
    
            text(ax, 0.02, 0.78, ...
                sprintf('Quality = %.0f / 100', q(cell_id)), ...
                'Units','normalized', ...
                'Color',[0.15 0.15 0.15], ...
                'FontWeight','bold', ...
                'FontSize',11, ...
                'VerticalAlignment','top', ...
                'BackgroundColor',[1 1 1 0.6], ...
                'Margin',4);
        end
    end

    update_roi_zoom(fig);
    update_peak_histogram(fig);
end

function update_peak_histogram(fig)
    axH = getappdata(fig,'axH');
    if isempty(axH) || ~ishghandle(axH)
        return;
    end

    if ~isappdata(fig,'n_peaks_all')
        cla(axH);
        title(axH,'# pics / cellule');
        return;
    end

    n_peaks_all = getappdata(fig,'n_peaks_all');
    if isempty(n_peaks_all)
        cla(axH);
        title(axH,'# pics / cellule');
        return;
    end

    % cellules actuellement affichées / validées dans la navigation
    if isappdata(fig,'order_cells')
        order_cells = getappdata(fig,'order_cells');
    else
        order_cells = [];
    end

    if isempty(order_cells)
        cla(axH);
        title(axH,'# pics / cellule');
        xlabel(axH,'Nombre de pics');
        ylabel(axH,'Nombre de cellules');
        box(axH,'on');
        return;
    end

    n_peaks_show = n_peaks_all(order_cells);

    % cellule courante
    xcur = NaN;
    cid = NaN;
    if isappdata(fig,'cell_id')
        cid = getappdata(fig,'cell_id');
        if ~isempty(cid) && isscalar(cid) && cid>=1 && cid<=numel(n_peaks_all)
            xcur = n_peaks_all(cid);
        end
    end

    cla(axH);
    hold(axH,'on');
    histogram(axH, n_peaks_show, 'BinMethod','integers');

    if isfinite(xcur)
        xline(axH, xcur, 'k--', 'LineWidth', 1.5);
        title(axH, sprintf('Cellule %d : %d pics', cid, xcur));
    else
        title(axH,'# pics / cellule');
    end

    xlabel(axH,'Nombre de pics');
    ylabel(axH,'Nombre de cellules');
    box(axH,'on');
end

function h = create_badframe_patch(ax, segs)
    if isempty(segs) || isempty(ax) || ~ishghandle(ax)
        h = gobjects(1);
        return;
    end

    yl = ylim(ax);
    [X, Y] = segs_to_patchXY(segs, yl);

    h = patch(ax, X, Y, [1 0 0], ...
        'FaceAlpha', 0.25, ...
        'EdgeColor', 'none', ...
        'HitTest', 'off');

    set(h,'XLimInclude','off','YLimInclude','off');
    uistack(h,'bottom');
end

function update_badframe_patch(h, segs, yl)
    if isempty(h) || ~isgraphics(h) || isempty(segs) || numel(yl)~=2
        return;
    end
    [X, Y] = segs_to_patchXY(segs, yl);
    set(h, 'XData', X, 'YData', Y);
end

function [X, Y] = segs_to_patchXY(segs, yl)
    y0 = yl(1); y1 = yl(2);

    n = size(segs,1);
    X = nan(1, 5*n);
    Y = nan(1, 5*n);

    for k = 1:n
        a = segs(k,1);
        b = segs(k,2);

        ii = (k-1)*5 + (1:5);
        X(ii) = [a b b a a];
        Y(ii) = [y0 y0 y1 y1 y0];
    end
end

function update_roi_zoom(fig)

    if ~isappdata(fig,'axROI')
        return;
    end
    ax = getappdata(fig,'axROI');
    if isempty(ax) || ~ishghandle(ax)
        return;
    end

    % ----------------------------
    % Image moyenne
    % ----------------------------
    meanImg = [];
    if isappdata(fig,'meanImg')
        meanImg = getappdata(fig,'meanImg');
    end

    if isempty(meanImg) || ~(isnumeric(meanImg) || islogical(meanImg))
        cla(ax);
        title(ax,'ROI indisponible');
        return;
    end
    meanImg = double(meanImg);

    % ----------------------------
    % Cellule courante
    % ----------------------------
    if ~isappdata(fig,'cell_id')
        cla(ax);
        imagesc(ax, meanImg);
        colormap(ax, gray);
        axis(ax, 'image');
        set(ax,'YDir','reverse');
        title(ax,'ROI indisponible');
        return;
    end

    cid = round(getappdata(fig,'cell_id'));

    % ----------------------------
    % Récupération masque (stack N x H x W)
    % ----------------------------
    mask = [];
    if isappdata(fig,'masks')
        masks = getappdata(fig,'masks');
        pixel_size_um = getappdata(fig,'pixel_size_um');

        if ~isempty(masks) && (isnumeric(masks) || islogical(masks)) && ndims(masks) >= 3
            if cid >= 1 && cid <= size(masks,1)
                mask = squeeze(masks(cid,:,:));
            end
        end
    end

    if isempty(mask)
        cla(ax);
        imagesc(ax, meanImg);
        colormap(ax, gray);
        axis(ax, 'image');
        set(ax,'YDir','reverse');
        title(ax, sprintf('Cellule %d (masque indisponible)', cid));
        add_scale_bar(ax, pixel_size_um);
        return;
    end

    mask = logical(mask);

    if ~ismatrix(mask) || ~any(mask(:))
        cla(ax);
        imagesc(ax, meanImg);
        colormap(ax, gray);
        axis(ax, 'image');
        set(ax,'YDir','reverse');
        title(ax, sprintf('Cellule %d (masque vide)', cid));
        add_scale_bar(ax, pixel_size_um);
        return;
    end

    % ----------------------------
    % Vérif dimensions
    % ----------------------------
    [Himg, Wimg] = size(meanImg);
    [Hm, Wm] = size(mask);

    if Himg ~= Hm || Wimg ~= Wm
        cla(ax);
        imagesc(ax, meanImg);
        colormap(ax, gray);
        axis(ax, 'image');
        set(ax,'YDir','reverse');
        title(ax, sprintf('Cellule %d (taille masque/image incompatible)', cid));
        add_scale_bar(ax, pixel_size_um);
        return;
    end

    % ----------------------------
    % Bounding box auto
    % ----------------------------
    [y, x] = find(mask);
    pad = 12;

    xmin = max(1, floor(min(x)) - pad);
    xmax = min(size(meanImg,2), ceil(max(x)) + pad);
    ymin = max(1, floor(min(y)) - pad);
    ymax = min(size(meanImg,1), ceil(max(y)) + pad);

    cropImg  = meanImg(ymin:ymax, xmin:xmax);
    cropMask = mask(ymin:ymax, xmin:xmax);

    % ----------------------------
    % Contraste auto
    % ----------------------------
    v = cropImg(isfinite(cropImg));
    if isempty(v)
        lo = min(cropImg(:));
        hi = max(cropImg(:));
    else
        lo = prctile(v, 5);
        hi = prctile(v, 99.5);
        if ~isfinite(lo) || ~isfinite(hi) || hi <= lo
            lo = min(v);
            hi = max(v);
        end
    end

    % ----------------------------
    % Affichage image
    % ----------------------------
    cla(ax);
    imagesc(ax, cropImg);
    colormap(ax, gray);
    axis(ax, 'image');
    set(ax,'YDir','reverse');
    clim(ax, [lo hi]);
    hold(ax,'on');

    % ----------------------------
    % Overlay masque (sans contour)
    % ----------------------------
    redOverlay = zeros([size(cropMask), 3]);
    redOverlay(:,:,1) = 1;

    hMask = imshow(redOverlay, 'Parent', ax);
    set(hMask, 'AlphaData', 0.30 * double(cropMask));

    % ----------------------------
    % Scale bar
    % ----------------------------
    add_scale_bar(ax, pixel_size_um);

    % ----------------------------
    % Titre
    % ----------------------------
    iscell_label = '';

    if isappdata(fig,'iscell_idx_display')
        iscell_idx_display = getappdata(fig,'iscell_idx_display');
    
        if ~isempty(iscell_idx_display) && ...
           cid >= 1 && cid <= numel(iscell_idx_display) && ...
           isfinite(iscell_idx_display(cid))
    
            iscell_label = sprintf(' | iscell idx %d', round(iscell_idx_display(cid)- 1));
        end
    end
    
    title(ax, sprintf('Cellule %d%s', cid, iscell_label), ...
        'Interpreter','none');

    hold(ax,'off');
end

function add_scale_bar(ax, pixel_size_um)

    if isempty(ax) || ~ishghandle(ax) || ~isfinite(pixel_size_um) || pixel_size_um <= 0
        return;
    end

    xl = xlim(ax);
    yl = ylim(ax);

    w = abs(diff(xl));
    h = abs(diff(yl));

    if w <= 0 || h <= 0
        return;
    end

    candidate_um = [5 10 20 25 50 100];
    target_um = 0.25 * w * pixel_size_um;
    [~, idx] = min(abs(candidate_um - target_um));
    bar_um = candidate_um(idx);

    bar_px = bar_um / pixel_size_um;

    x0 = xl(1) + 0.08 * w;
    x1 = x0 + bar_px;

    y0 = yl(1) + 0.92 * h;

    plot(ax, [x0 x1], [y0 y0], 'k-', 'LineWidth', 5, 'Clipping', 'off');
    plot(ax, [x0 x1], [y0 y0], 'w-', 'LineWidth', 3, 'Clipping', 'off');

    text(ax, (x0+x1)/2, y0 - 0.04*h, sprintf('%g \\mum', bar_um), ...
        'Color','w', 'FontWeight','bold', 'HorizontalAlignment','center', ...
        'VerticalAlignment','bottom', 'Clipping','off', ...
        'BackgroundColor','k', 'Margin',1);
end

%% ===================== GUI PARAMETERS =====================

function make_slider(parent,fig,label,field,minv,maxv,val,pos)

    intFields = {'savgol_win_ms','window_size_s','refrac_ms'};

    if ismember(field,intFields)
        val = round(max(minv, min(maxv, val)));
        fmt = '%s = %d';
    else
        val = max(minv, min(maxv, val));
        fmt = '%s = %.2f';
    end

    uicontrol('Parent',parent,'Style','text', ...
        'String',sprintf(fmt,label,val), ...
        'Units','normalized', ...
        'Position',[pos(1) pos(2)+0.05 pos(3) 0.04], ...
        'Tag',['lbl_' field], ...
        'HorizontalAlignment','left', ...
        'FontWeight','normal');

    uicontrol('Parent',parent,'Style','slider', ...
        'Min',minv, ...
        'Max',maxv, ...
        'Value',val, ...
        'Units','normalized', ...
        'Position',pos, ...
        'Callback',@(src,~) update_param(fig,field,get(src,'Value')));
end

function update_param(fig, field, value)

    viewer_mode = isappdata(fig,'viewer_mode') && getappdata(fig,'viewer_mode');

    opts = getappdata(fig,'opts');
    fs   = getappdata(fig,'fs');

    intFields = {'savgol_win_ms','window_size_s','refrac_ms'};

    if ismember(field,intFields)
        value = round(value);
        value = max(0, value);
    else
        value = max(0, value);
    end

    opts.(field) = value;
    opts = convert_opts_ms_to_frames(opts, fs);
    setappdata(fig,'opts',opts);

    lbl = findobj(fig,'Tag',['lbl_' field]);
    if ~isempty(lbl)
        eqPos = strfind(lbl.String,'=');
        if ~isempty(eqPos)
            base = strtrim(lbl.String(1:eqPos(1)-1));
        else
            base = field;
        end

        if ismember(field,intFields)
            lbl.String = sprintf('%s = %d', base, value);
        else
            lbl.String = sprintf('%s = %.2f', base, value);
        end
    end

    if viewer_mode
        auto_detect_and_add(fig);
        drawnow;
        return;
    end

    if ~isappdata(fig,'cell_id')
        return;
    end

    cid = getappdata(fig,'cell_id');

    if isempty(cid) || ~isscalar(cid) || ~isfinite(cid)
        return;
    end

    cid = round(cid);

    DF_sg = getappdata(fig,'DF_sg');

    if cid < 1 || cid > size(DF_sg,1)
        return;
    end

    if isappdata(fig,'bad_frames')
        bad_frames = getappdata(fig,'bad_frames');
    else
        bad_frames = [];
    end

    % =====================================================
    % Cas 1 : paramètre qui modifie la trace affichée
    % -> recalcul uniquement de la cellule courante
    % =====================================================
    if ismember(field, {'window_size_s','savgol_win_ms'})

        F = getappdata(fig,'F_raw');

        if isempty(F) || cid > size(F,1)
            return;
        end

        F_cell = F(cid,:);

        [DF_raw_cell, F0_cell] = F_processing(F_cell, bad_frames, fs, opts.window_size);

        DF_sg_cell = savgol_transform(DF_raw_cell, opts);
        noise_cell = estimate_noise(DF_raw_cell);

        DF_raw    = getappdata(fig,'DF_raw');
        DF_sg     = getappdata(fig,'DF_sg');
        F0        = getappdata(fig,'F0');
        noise_est = getappdata(fig,'noise_est');

        if isempty(DF_raw) || size(DF_raw,1) ~= size(F,1)
            DF_raw = nan(size(F));
        end

        if isempty(DF_sg) || size(DF_sg,1) ~= size(F,1)
            DF_sg = nan(size(F));
        end

        if isempty(F0) || size(F0,1) ~= size(F,1)
            F0 = nan(size(F));
        end

        if isempty(noise_est) || numel(noise_est) ~= size(F,1)
            noise_est = nan(size(F,1),1);
        else
            noise_est = noise_est(:);
        end

        DF_raw(cid,:)     = DF_raw_cell;
        DF_sg(cid,:)      = DF_sg_cell;
        F0(cid,:)         = F0_cell;
        noise_est(cid,1)  = noise_cell;

        setappdata(fig,'DF_raw',DF_raw);
        setappdata(fig,'DF_sg',DF_sg);
        setappdata(fig,'F0',F0);
        setappdata(fig,'noise_est',noise_est);
    end

    % =====================================================
    % Cas 2 : prominence / réfractaire
    % -> pas de recalcul global, seulement pics cellule courante
    % =====================================================
    setappdata(fig,'autotervals', []);
    setappdata(fig,'auto_peaks', []);

    if isappdata(fig,'seuil_detection_last')
        rmappdata(fig,'seuil_detection_last');
    end

    auto_detect_and_add(fig);

    % Met à jour seulement le nombre de pics de la cellule courante
    if isappdata(fig,'auto_peaks') && isappdata(fig,'n_peaks_all')
        auto_peaks = getappdata(fig,'auto_peaks');
        n_peaks_all = getappdata(fig,'n_peaks_all');

        if cid >= 1 && cid <= numel(n_peaks_all)
            n_peaks_all(cid) = numel(auto_peaks);
            setappdata(fig,'n_peaks_all', n_peaks_all);
        end
    end

    refresh_data(fig);
    drawnow;
end

function request_reprocess_from_viewer(fig)
    setappdata(fig,'request_reprocess',true);
    uiresume(fig);
end