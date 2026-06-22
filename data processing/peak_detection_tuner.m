function [F0, noise_est, valid_cells, DF_sg, DF_raw, drift_score, Raster, Acttmp2, MAct, thresholds, focus_segs, opts, has_new_outputs] = ...
    peak_detection_tuner(F, fs, synchronous_frames, varargin)

    % ---- Options détection (valeurs initiales) ----
    opts = struct( ...
        'window_size_s', 60, ...
        'savgol_win_ms', 300, ...
        'savgol_poly', 3, ...
        'refrac_ms', 300, ...
        'prominence_factor', 1, ...
        'min_n_peaks_cutoff', 10, ...
        'min_mask_um2', 50, ...
        'max_drift_score', 0.15, ...
        'min_mask_connectivity', 0.80, ...
        'min_quality_percentile_for_high_drift', 70 ...
    );
    opts = convert_opts_ms_to_frames(opts, fs);
    
    % ---- Inputs optionnels ----
    iscell_idx = [];
    stat   = [];
    deviation = [];
    bad_frames = [];
    focus_segs = [];
    gcamp_TSeries_path = '';
    gcamp_output_folder = '';
    meanImg = [];
    ops = [];
    metadata = [];
    viewer_mode = false;
    cell_type = '';
    masks = [];
    blue_indices = [];
    stim_frames = [];
    motion_energy = [];
    
    DF_raw = [];
    drift_score = [];
    DF_sg = [];
    F0 = [];
    noise_est = [];

    Raster = [];
    Acttmp2 = [];
    thresholds = [];
    valid_cells = [];


    if ~isempty(varargin)

        if mod(numel(varargin),2) ~= 0
            warning('peak_detection_tuner:varargin', ...
                'varargin doit être en paires clé/valeur. Dernier argument ignoré.');
            varargin = varargin(1:end-1);
        end

        for i = 1:2:numel(varargin)
            key = varargin{i};

            if ~(ischar(key) || (isstring(key) && isscalar(key)))
                warning('peak_detection_tuner:badKey', ...
                    'Clé varargin #%d invalide (type %s). Paire ignorée.', i, class(key));
                continue;
            end

            val = varargin{i+1};

            switch char(key)
                case 'viewer_mode'
                    viewer_mode = logical(val);

                case 'DF_sg'
                    DF_sg = val;
                
                case 'DF_raw'
                    DF_raw = val;
                
                case 'drift_score'
                    drift_score = val;

                case 'F0'
                    F0 = val;

                case 'noise_est'
                    noise_est = val;

                case 'Raster'
                    Raster = val;

                case 'Acttmp2'
                    Acttmp2 = val;

                case 'thresholds'
                    thresholds = val;

                case 'valid_cells'
                    valid_cells = val;

                case 'cell_type'
                    cell_type = char(val);

                case 'ops'
                    ops = val;

                case 'iscell_idx'
                    iscell_idx = val;

                case 'stat'
                    stat = val;

                 case 'masks'
                    masks = val;

                case 'blue_indices'
                    blue_indices = val;

                case 'meanImg'
                    meanImg = val;

                case 'gcamp_TSeries_path'
                    gcamp_TSeries_path = val;

                case 'deviation'
                    deviation = val;
                
                case 'bad_frames'
                    bad_frames = val;

                case 'focus_segs'
                    focus_segs = val;

                case 'metadata'
                    metadata = val;

                case 'stim_frames'
                    stim_frames = val;

                case 'motion_energy'
                    motion_energy = val;
                 
                case 'gcamp_output_folder'
                    gcamp_output_folder = val;
            end
        end
    end
    
    % ---- Prétraitement ----
    window_size = opts.window_size;
    
    if viewer_mode
    
        if ~isempty(DF_sg) && size(DF_sg,1) == size(F,1)
    
            if isempty(F0) || size(F0,1) ~= size(F,1)
                F0 = nan(size(F));
            end
    
            if ~isempty(noise_est) && numel(noise_est) == size(F,1)
                noise_est = noise_est(:);
            else
                noise_est = estimate_noise(DF_sg);
            end
    
            if isempty(DF_raw) || size(DF_raw,1) ~= size(F,1)
                DF_raw = [];
            end
    
            if isempty(drift_score) || numel(drift_score) ~= size(F,1)
                drift_score = zeros(size(F,1),1);
            else
                drift_score = drift_score(:);
            end
    
            [~, SNR, score, cells_sorted_by_quality, ~, ~, ~] = ...
                compute_snr_quality(DF_sg, noise_est, opts, bad_frames);
    
        else
            warning('viewer_mode demandé mais DF_sg sauvegardé absent/incompatible. Recalcul normal.');
            viewer_mode = false;
        end
    end
    
    if ~viewer_mode

        %results = optimize_F0_window_from_F(F, bad_frames, fs);
    
        [DF_raw, F0] = F_processing(F, bad_frames, fs, window_size);

        DF_sg = savgol_transform(DF_raw, opts);
        noise_est = estimate_noise(DF_raw);
    
        [~, SNR, score, cells_sorted_by_quality, ~, ~, ~] = ...
            compute_snr_quality(DF_sg, noise_est, opts, bad_frames);
    end

    % ---- Titre fenêtre ----
    nCells = size(F,1);
    title_parts = {};

    if viewer_mode
        title_parts{end+1} = '[VIEWER MODE]';
    end

    if ~isempty(cell_type)
        title_parts{end+1} = cell_type;
    end

    % priorité au dossier de sortie en combined
    if strcmpi(cell_type, 'combined')
        if ~isempty(gcamp_output_folder)
            title_parts{end+1} = char(string(gcamp_output_folder));
        elseif ~isempty(gcamp_TSeries_path)
            title_parts{end+1} = char(string(fileparts(gcamp_TSeries_path)));
        end
    else
        if ~isempty(gcamp_TSeries_path)
            title_parts{end+1} = char(string(fileparts(gcamp_TSeries_path)));
        elseif ~isempty(gcamp_output_folder)
            title_parts{end+1} = char(string(gcamp_output_folder));
        end
    end

    title_parts{end+1} = sprintf('nCells=%d', nCells);

    winTitle = strjoin(title_parts, ' | ');
    
    % ===================== GUI =====================
    fig = figure('Name', winTitle, ...
        'NumberTitle','off', ...
        'Position',[100 100 1300 820], ...
        'Color',[.97 .97 .98]);

    set(fig,'KeyPressFcn', @(~,evnt) navigate_cells(fig, evnt));
    set(fig,'CloseRequestFcn',@(src,~) uiresume(src));

    ctrl_panel = uipanel('Parent',fig, ...
        'Units','normalized', ...
        'Position',[0.01 0.05 0.22 0.92], ...
        'Title','Contrôles', ...
        'FontSize',10, ...
        'Tag','ctrl_panel');

    % ---- Callbacks selon mode ----
    if viewer_mode
        validate_cb = @(~,~) [];
        keep_cb     = @(~,~) [];
        exclude_cb  = @(~,~) [];
    else
        validate_cb = @(~,~) validate_selection_filter(fig);
        keep_cb     = @(~,~) keep_cell(fig);
        exclude_cb  = @(~,~) exclude_cell(fig);
    end
    
    finalize_cb = @(~,~) finalize_and_close(fig, synchronous_frames);
    
    % ---- Navigation ----
    uicontrol('Parent',ctrl_panel,'Style','text', ...
        'String', sprintf('Navigation cellule (1 / %d)', size(F,1)), ...
        'Units','normalized', ...
        'Position',[0.05 0.935 0.90 0.03], ...
        'Tag','lbl_nav_cell', ...
        'HorizontalAlignment','left', ...
        'BackgroundColor',[.97 .97 .98], ...
        'FontWeight','bold');
    
    if size(F,1) > 1
        step_small = 1 / (size(F,1) - 1);
        step_big   = min(1, 10 / (size(F,1) - 1));
    else
        step_small = 1;
        step_big   = 1;
    end
    
    uicontrol('Parent',ctrl_panel,'Style','slider', ...
        'Min', 1, ...
        'Max', max(1, size(F,1)), ...
        'Value', 1, ...
        'SliderStep', [step_small step_big], ...
        'Units','normalized', ...
        'Position',[0.05 0.865 0.90 0.055], ...
        'Tag','sldr_nav_cell', ...
        'Callback', @(src,~) update_current_cell(fig, round(get(src,'Value'))));
    
    uicontrol('Parent',ctrl_panel,'Style','pushbutton', ...
        'String','Appliquer cutoff', ...
        'Units','normalized', ...
        'Position',[0.05 0.17 0.90 0.055], ...
        'BackgroundColor',[0.20 0.45 0.90], ...
        'ForegroundColor','w', ...
        'FontWeight','bold', ...
        'FontSize',12, ...
        'Callback', validate_cb);
    
    % ---- Manuel ----
    uicontrol('Parent',ctrl_panel,'Style','pushbutton', ...
        'String','Garder cellule', ...
        'Units','normalized', ...
        'Position',[0.05 0.095 0.42 0.055], ...
        'BackgroundColor',[0.10 0.60 0.10], ...
        'ForegroundColor','w', ...
        'FontWeight','bold', ...
        'FontSize',11, ...
        'Callback', keep_cb);
    
    uicontrol('Parent',ctrl_panel,'Style','pushbutton', ...
        'String','Exclure cellule', ...
        'Units','normalized', ...
        'Position',[0.53 0.095 0.42 0.055], ...
        'BackgroundColor',[0.80 0.15 0.15], ...
        'ForegroundColor','w', ...
        'FontWeight','bold', ...
        'FontSize',11, ...
        'Callback', exclude_cb);
    
    % ---- Final ----
    uicontrol('Parent',ctrl_panel,'Style','pushbutton', ...
        'String','Confirmer sélection', ...
        'Units','normalized', ...
        'Position',[0.05 0.02 0.90 0.06], ...
        'BackgroundColor',[0.1 0.6 0.35], ...
        'ForegroundColor','w', ...
        'FontWeight','bold', ...
        'FontSize',12, ...
        'Callback', finalize_cb);
    
    if viewer_mode
        set(findobj(ctrl_panel,'String','Appliquer cutoff'),   'Enable','off');
        set(findobj(ctrl_panel,'String','Garder cellule'),     'Enable','off');
        set(findobj(ctrl_panel,'String','Exclure cellule'),    'Enable','off');
        set(findobj(ctrl_panel,'String','Confirmer sélection'),'Enable','off');
    end

    % ---- Contrôles détection ----
    make_slider(ctrl_panel,fig,'Window size (sec)','window_size_s',1,300,opts.window_size_s,[0.05 0.76 0.90 0.06]);
    make_slider(ctrl_panel,fig, ...
    'Prominence', ...
    'prominence_factor', ...
    0,1,1, ...
    [0.05 0.60 0.90 0.06]);
    make_slider(ctrl_panel,fig,'Réfractaire (ms)','refrac_ms',0,5000,opts.refrac_ms,[0.05 0.52 0.90 0.06]);
    make_slider(ctrl_panel,fig,'SavGol window (ms)','savgol_win_ms',100,500,opts.savgol_win_ms,[0.05 0.44 0.90 0.06]);
    
    % ---- Axe principal ----
    ax1 = axes('Parent',fig,'Position',[0.28 0.63 0.70 0.30]);
    box(ax1,'on');
    xlabel(ax1,'Frames');
    ylabel(ax1,'\DeltaF/F (SavGol)');
    plot(ax1,NaN,NaN,'k-');
    hold(ax1,'on');
    
    % ---- Axe F0 ----
    axF0 = axes('Parent',fig,'Position',[0.28 0.55 0.70 0.06]);
    box(axF0,'on');
    ylabel(axF0,'F0');
    set(axF0,'XTickLabel',[]);
    cla(axF0);
    hold(axF0,'on');
    
    % ---- Axe déviation ----
    axDev = axes('Parent',fig,'Position',[0.28 0.47 0.70 0.06]);
    box(axDev,'on');
    ylabel(axDev,'Dev');
    set(axDev,'XTickLabel',[]);
    cla(axDev);
    hold(axDev,'on');

    % ---- Axe motion energy ----
    axMotion = axes('Parent',fig,'Position',[0.28 0.41 0.70 0.045]);
    box(axMotion,'on');
    ylabel(axMotion,'Motion');
    set(axMotion,'XTickLabel',[]);
    cla(axMotion);
    hold(axMotion,'on');

    % ---- ROI ----
    axROI = axes('Parent',fig,'Position',[0.28 0.06 0.30 0.30]);
    box(axROI,'on');
    title(axROI,'ROI (zoom)');
    axis(axROI,'image');

    % ---- Histogramme ----
    axH   = axes('Parent',fig,'Position',[0.62 0.06 0.35 0.30]);
    box(axH,'on');
    title(axH,'# pics / cellule');
    xlabel(axH,'Nombre de pics');
    ylabel(axH,'Nombre de cellules');

   % ---- Appdata ----
    setappdata(fig,'fs',fs);   
    setappdata(fig,'F_raw',F);
    setappdata(fig,'DF_sg', DF_sg);
    setappdata(fig,'DF_raw', DF_raw);
    setappdata(fig,'drift_score', drift_score);
    setappdata(fig,'F0',F0);
    setappdata(fig,'noise_est',noise_est);
    setappdata(fig,'SNR',SNR);
    setappdata(fig,'score_quality', score);

    score_quality_percentile = nan(size(score));

    valid_score = isfinite(score);
    [~, order_score] = sort(score(valid_score), 'ascend');
    
    tmp = nan(sum(valid_score),1);
    tmp(order_score) = linspace(0,100,sum(valid_score));
    
    score_quality_percentile(valid_score) = tmp;
    
    setappdata(fig,'score_quality_percentile', score_quality_percentile);

    setappdata(fig,'opts',opts);
    setappdata(fig,'motion_energy',motion_energy);
    
    
    setappdata(fig,'ax1',ax1);
    setappdata(fig,'axF0',axF0);
    setappdata(fig,'axDev',axDev);
    setappdata(fig,'axMotion',axMotion);
    setappdata(fig,'axROI',axROI);
    setappdata(fig,'axH',axH);
    
    setappdata(fig,'deviation', deviation);
    setappdata(fig,'bad_frames', bad_frames);
    setappdata(fig,'focus_segs', focus_segs);

    setappdata(fig,'stim_frames', stim_frames);
    
    setappdata(fig,'cells_sorted_by_quality', cells_sorted_by_quality);

    % ---- iscell_idx affichable, aligné sur les lignes de F ----
    iscell_idx_display = nan(size(F,1),1);
    
    if ~isempty(iscell_idx)
    
        iscell_idx = iscell_idx(:);
    
        if strcmpi(cell_type,'combined') && ~isempty(blue_indices)
    
            blue_indices = round(blue_indices(:));
            blue_indices = blue_indices(isfinite(blue_indices));
            blue_indices = blue_indices(blue_indices >= 1 & blue_indices <= size(F,1));
    
            is_blue = false(size(F,1),1);
            is_blue(blue_indices) = true;
    
            gcamp_rows = find(~is_blue);
    
            n = min(numel(gcamp_rows), numel(iscell_idx));
            iscell_idx_display(gcamp_rows(1:n)) = iscell_idx(1:n);
    
        else
    
            n = min(size(F,1), numel(iscell_idx));
            iscell_idx_display(1:n) = iscell_idx(1:n);
        end
    end

    setappdata(fig,'iscell_idx_display', iscell_idx_display);

    setappdata(fig,'stat', stat);
    setappdata(fig,'meanImg', meanImg);
    setappdata(fig,'metadata', metadata);
    setappdata(fig,'viewer_mode', viewer_mode);
    setappdata(fig,'blue_indices', blue_indices);
    
    % ---- Données de détection sauvegardées pour viewer mode ----
    setappdata(fig,'Raster_saved', Raster);
    setappdata(fig,'Acttmp2_saved', Acttmp2);
    setappdata(fig,'thresholds_saved', thresholds);
    setappdata(fig,'valid_cells_saved', valid_cells);
    
    % cell_status: 0 undecided, +1 keep, -1 exclude
    setappdata(fig,'cell_status', zeros(size(F,1),1));

    setappdata(fig,'gcamp_output_folder', gcamp_output_folder);

    setappdata(fig,'masks', masks);
    
    pixel_size_um = NaN;
    mask_sizes = [];
    mask_connectivity_ratio = [];
    
    if ~isempty(masks) && (isnumeric(masks) || islogical(masks)) && ndims(masks) >= 3
    
        pixel_size_um = NaN;
    
        if isappdata(fig,'metadata')
            metadata = getappdata(fig,'metadata');
    
            try
                if isstruct(metadata) && isfield(metadata, 'PixelSize_um') && ~isempty(metadata.PixelSize_um)
                    px = metadata.PixelSize_um;
    
                    if isnumeric(px)
                        pixel_size_um = double(px(1));
                    elseif iscell(px) && ~isempty(px)
                        pixel_size_um = double(px{1});
                    else
                        pixel_size_um = NaN;
                    end
                end
            catch
                pixel_size_um = NaN;
            end
        end
    
        nCells_masks = size(masks,1);
        mask_sizes = nan(nCells_masks,1);
        mask_connectivity_ratio = nan(nCells_masks,1);
    
        for i = 1:nCells_masks
    
            m = squeeze(masks(i,:,:)) > 0;
    
            if isempty(m) || ~any(m(:))
                continue;
            end
    
            npix = sum(m(:));
    
            if isfinite(pixel_size_um) && pixel_size_um > 0
                mask_sizes(i) = npix * (pixel_size_um^2);
            else
                mask_sizes(i) = NaN;
            end
    
            CC = bwconncomp(m, 8);
    
            if CC.NumObjects > 0
                comp_sizes = cellfun(@numel, CC.PixelIdxList);
                mask_connectivity_ratio(i) = max(comp_sizes) / sum(comp_sizes);
            end
        end
    end
    
    setappdata(fig,'pixel_size_um', pixel_size_um);
    setappdata(fig,'mask_sizes', mask_sizes);
    setappdata(fig,'mask_connectivity_ratio', mask_connectivity_ratio);

    if viewer_mode
        % en mode viewer : toutes les cellules sont visibles directement
        order_cells_all = (1:size(F,1)).';
        order_cells     = order_cells_all;
    
        setappdata(fig,'order_cells_all', order_cells_all);
        setappdata(fig,'order_cells',     order_cells);
    
        setappdata(fig,'current_rank', 1);
        setappdata(fig,'nav_rank', 1);
        setappdata(fig,'cutoff_rank', 1);
    
        if ~isempty(order_cells)
            setappdata(fig,'cell_id', order_cells(1));
        else
            setappdata(fig,'cell_id', 1);
        end
    
        % cutoff inactif en viewer mode
        setappdata(fig,'cutoff_locked', true);
        setappdata(fig,'cutoff_validated', false);
    
    else
        % mode normal : navigation selon qualité
        setappdata(fig,'order_cells_all', cells_sorted_by_quality);
        setappdata(fig,'order_cells',     cells_sorted_by_quality);
    
        setappdata(fig,'current_rank', 1);
        setappdata(fig,'nav_rank', 1);
        setappdata(fig,'cutoff_rank', 1);
    
        if ~isempty(cells_sorted_by_quality)
            setappdata(fig,'cell_id', cells_sorted_by_quality(1));
        else
            setappdata(fig,'cell_id', 1);
        end
    
        setappdata(fig,'cutoff_locked', false);
        setappdata(fig,'cutoff_validated', false);
    end

    % ---- Déviation ----
    dev = getappdata(fig,'deviation');
    dev = dev(:).';
    tDev = 1:numel(dev);

    if ~isempty(dev)
        hDev = plot(axDev, tDev, dev, 'k-','HitTest','off');
        setappdata(fig,'hDev', hDev);
    else
        text(axDev,0.5,0.5,'deviation vide','Units','normalized','HorizontalAlignment','center');
    end

    dv = dev(isfinite(dev));
    if ~isempty(dv)
        lo = prctile(dv, 2);
        hi = prctile(dv, 98);
        if isfinite(lo) && isfinite(hi) && hi > lo
            pad = 0.1*(hi-lo);
            ylim(axDev, [lo-pad, hi+pad]);
        end
    end

    % Motion energy
    motion_energy = getappdata(fig,'motion_energy');

    if ~isempty(motion_energy)
    
        motion_energy = motion_energy(:).';
    
        plot(axMotion, ...
             1:numel(motion_energy), ...
             motion_energy, ...
             'k-', ...
             'HitTest','off');
    
    else
    
        text(axMotion,0.5,0.5,'motion energy vide', ...
            'Units','normalized', ...
            'HorizontalAlignment','center');
    
    end
    
   if ~isempty(focus_segs)
        hBad1 = create_badframe_patch(ax1, focus_segs);
        setappdata(fig,'hBadPatch_ax1', hBad1);
    
        hBadF0 = create_badframe_patch(axF0, focus_segs);
        setappdata(fig,'hBadPatch_axF0', hBadF0);
    
        hBadDev = create_badframe_patch(axDev, focus_segs);
        setappdata(fig,'hBadPatch_axDev', hBadDev);
   end

    hBadMotion = create_badframe_patch(axMotion, focus_segs);
    setappdata(fig,'hBadPatch_axMotion', hBadMotion);

    linkaxes([ax1 axF0 axDev axMotion],'x');

    % ---- Pics / sélection ----
    if viewer_mode

        % En viewer mode : NE PAS redétecter.
        % On utilise uniquement les pics sauvegardés.
        nCells = size(F,1);
        n_peaks_all = zeros(nCells,1);

        if ~isempty(Acttmp2)
            for cid = 1:min(nCells, numel(Acttmp2))
                if iscell(Acttmp2)
                    n_peaks_all(cid) = numel(Acttmp2{cid});
                else
                    n_peaks_all(cid) = 0;
                end
            end
        elseif ~isempty(Raster)
            n_peaks_all = sum(logical(Raster), 2);
            n_peaks_all = n_peaks_all(:);
        end

        setappdata(fig,'n_peaks_all', n_peaks_all);

    else

        % Mode normal : détection active
        recompute_n_peaks_all(fig);
        apply_auto_cutoff(fig);

        n_peaks_all = getappdata(fig,'n_peaks_all');
        cell_status = getappdata(fig,'cell_status');
        zero_peak_cells = (n_peaks_all == 0);
        cell_status(zero_peak_cells) = -1;
        setappdata(fig,'cell_status', cell_status);
    end

    refresh_selection_order(fig);
    update_current_cell(fig, 1);
    drawnow;

    uiwait(fig);
    has_new_outputs = false;

    % ---- Sorties ----
    if ishghandle(fig) && isappdata(fig,'last_save_outputs')
        out = getappdata(fig,'last_save_outputs');

        has_new_outputs = true;
        valid_cells = out.valid_cells;
        DF_raw      = out.DF_raw;
        DF_sg       = out.DF_sg;
        drift_score = out.drift_score;
        F0          = out.F0;
        Raster      = out.Raster;
        Acttmp2     = out.Acttmp2;
        MAct        = out.MAct;
        thresholds  = out.thresholds;

        if isfield(out,'summary')
            s = out.summary;
        
            fprintf('\n===== RÉCAPITULATIF SÉLECTION CELLULES =====\n');
            fprintf('Total cellules                   : %d\n', s.n_total);
            fprintf('Cellules sans pics (auto exclues): %d\n', s.n_zero_peaks);
            fprintf('Manuelles KEEP                   : %d\n', s.n_manual_keep);
            fprintf('Manuelles EXCLUES                : %d\n', s.n_manual_excl);
            fprintf('Validées par cutoff              : %d\n', s.n_kept_by_cutoff);
        
            if isfield(s,'n_blue_total')
                fprintf('Cellules électroporées total     : %d\n', s.n_blue_total);
            end
            if isfield(s,'n_blue_pass_cutoff')
                fprintf('Électroporées passant cutoff     : %d\n', s.n_blue_pass_cutoff);
            end
            if isfield(s,'n_blue_kept_final')
                fprintf('Électroporées gardées final      : %d\n', s.n_blue_kept_final);
            end
        
            fprintf('---------------------------------------------\n');
            fprintf('Cellules finales gardées         : %d\n', s.n_kept_final);
            fprintf('=============================================\n\n');
        end
    else
        Raster     = false(size(F));
        Acttmp2    = repmat({[]}, size(F,1),1);
        MAct       = [];
        thresholds = nan(size(F,1),1);
        valid_cells = [];
        DF_sg = [];
        DF_raw = [];
        drift_score = [];
        F0 = [];
    end

    if ishghandle(fig)
        delete(fig);
    end
end

%% ===================== PIPELINE CORE =====================

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

%% ===================== DETECTION / SAVE =====================
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

function [invalid_cells, valid_cells, DF, F0, Raster, Acttmp2, MAct, thresholds, opts, summary] = ...
    save_peak_matrix(fig, synchronous_frames)

    DF     = getappdata(fig,'DF_sg');
    opts      = getappdata(fig,'opts');
    noise_est = getappdata(fig,'noise_est');
    F0        = getappdata(fig,'F0');

    if isappdata(fig,'bad_frames')
        bad_frames = getappdata(fig,'bad_frames');
    else
        bad_frames = [];
    end

    nCells = size(DF,1);
    Nz     = size(DF,2);

    if isappdata(fig,'cell_status')
        cell_status = getappdata(fig,'cell_status');
    else
        cell_status = zeros(nCells,1);
    end

    if isappdata(fig,'n_peaks_all')
        n_peaks_all = getappdata(fig,'n_peaks_all');
    else
        n_peaks_all = zeros(nCells,1);
    end

    Raster     = false(nCells, Nz);
    Acttmp2    = cell(nCells,1);
    thresholds = nan(nCells,1);
    keep_mask = false(nCells,1);

    cutoff_validated = isappdata(fig,'cutoff_validated') && getappdata(fig,'cutoff_validated');

    if isappdata(fig,'n_peaks_all') && isappdata(fig,'opts')

        n_peaks_all = getappdata(fig,'n_peaks_all');
        opts = getappdata(fig,'opts');
    
        mask_sizes = [];
        if isappdata(fig,'mask_sizes')
            mask_sizes = getappdata(fig,'mask_sizes');
        end
    
        good_by_peaks = n_peaks_all >= opts.min_n_peaks_cutoff;
    
        if ~isempty(mask_sizes) && numel(mask_sizes) == numel(n_peaks_all)
            good_by_mask = mask_sizes >= opts.min_mask_um2;
        else
            good_by_mask = true(size(n_peaks_all));
        end

        mask_connectivity_ratio = [];
        if isappdata(fig,'mask_connectivity_ratio')
            mask_connectivity_ratio = getappdata(fig,'mask_connectivity_ratio');
        end
        
        if ~isempty(mask_connectivity_ratio) && numel(mask_connectivity_ratio) == numel(n_peaks_all)
            good_by_connectivity = mask_connectivity_ratio >= opts.min_mask_connectivity;
        else
            good_by_connectivity = true(size(n_peaks_all));
        end

        drift_score = [];
        if isappdata(fig,'drift_score')
            drift_score = getappdata(fig,'drift_score');
        end
        
        score_quality_percentile = [];
        if isappdata(fig,'score_quality_percentile')
            score_quality_percentile = getappdata(fig,'score_quality_percentile');
        end
        
        if ~isempty(drift_score) && ...
           ~isempty(score_quality_percentile) && ...
           numel(drift_score) == numel(n_peaks_all) && ...
           numel(score_quality_percentile) == numel(n_peaks_all)
        
            good_by_drift = ...
                (drift_score <= opts.max_drift_score) | ...
                (score_quality_percentile >= opts.min_quality_percentile_for_high_drift);
        
        else
        
            good_by_drift = true(size(n_peaks_all));
        end

        selected_cells_from_cutoff = find( ...
            good_by_peaks & ...
            good_by_mask & ...
            good_by_connectivity & ...
            good_by_drift);
    
    else
        selected_cells_from_cutoff = [];
    end

    n_kept = 0;

    for cid = 1:nCells

        if cell_status(cid) == -1
            Acttmp2{cid} = [];
            thresholds(cid) = NaN;
            Raster(cid,:) = false;
            continue;
        end

        force_keep = (cell_status(cid) == +1);

        if ~force_keep && ~ismember(cid, selected_cells_from_cutoff)
            Acttmp2{cid} = [];
            thresholds(cid) = NaN;
            Raster(cid,:) = false;
            continue;
        end

        x = DF(cid,:).';

        if isempty(x) || all(~isfinite(x))
            Acttmp2{cid} = [];
            thresholds(cid) = NaN;
            Raster(cid,:) = false;
            continue;
        end

        sigma = noise_est(cid);
        if ~isfinite(sigma) || sigma <= 0
            sigma = std(x,'omitnan');
        end
        if ~isfinite(sigma) || sigma <= 0
            sigma = eps;
        end

        out = detect_peaks_cell_core(x, sigma, opts, bad_frames);

        Acttmp2{cid}    = out.locs_raw;
        thresholds(cid) = out.threshold;

        if ~isempty(out.locs_raw)
            Raster(cid, out.locs_raw) = true;
        end

        keep_mask(cid) = true;
        n_kept = n_kept + 1;
    end

    fprintf('\n=> %d cellules conservées sur %d (%.1f%%)\n', ...
        n_kept, nCells, 100 * n_kept / max(1,nCells));

    if Nz > synchronous_frames
        MAct = zeros(1, Nz - synchronous_frames);
        for i = 1:(Nz - synchronous_frames)
            MAct(i) = sum(max(Raster(:, i:i+synchronous_frames), [], 2));
        end
    else
        MAct = zeros(1,0);
    end

    invalid_cells = ~keep_mask;
    valid_cells   = find(keep_mask);

    % -------------------------------------------------
    % Résumé final, incluant cellules électroporées
    % -------------------------------------------------
    blue_indices = [];
    if isappdata(fig,'blue_indices')
        blue_indices = getappdata(fig,'blue_indices');
    end

    if isempty(blue_indices)
        blue_indices = [];
    else
        blue_indices = round(blue_indices(:));
        blue_indices = blue_indices(isfinite(blue_indices) & blue_indices >= 1 & blue_indices <= nCells);
        blue_indices = unique(blue_indices);
    end

    if cutoff_validated
        blue_pass_cutoff = intersect(blue_indices, selected_cells_from_cutoff);
    else
        blue_pass_cutoff = [];
    end

    blue_kept_final = intersect(blue_indices, valid_cells);

    summary = struct();
    summary.n_total          = nCells;
    summary.n_zero_peaks     = sum(n_peaks_all == 0);
    summary.n_manual_keep    = sum(cell_status == +1);
    summary.n_manual_excl    = sum(cell_status == -1);
    summary.n_undecided      = sum(cell_status == 0);

    if cutoff_validated
        summary.n_kept_by_cutoff = sum( ...
            (cell_status == 0) & ismember((1:nCells)', selected_cells_from_cutoff) ...
        );
    else
        summary.n_kept_by_cutoff = 0;
    end

    summary.n_blue_total         = numel(blue_indices);
    summary.n_blue_pass_cutoff   = numel(blue_pass_cutoff);
    summary.blue_pass_cutoff_ids = blue_pass_cutoff;

    summary.n_blue_kept_final    = numel(blue_kept_final);
    summary.blue_kept_final_ids  = blue_kept_final;

    summary.n_kept_final = numel(valid_cells);

    DF      = DF(valid_cells, :);
    F0         = F0(valid_cells, :);
    thresholds = thresholds(valid_cells, :);
    Acttmp2    = Acttmp2(valid_cells);
    Raster     = Raster(valid_cells, :);
end

%% ===================== NAVIGATION / CUTOFF =====================

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

function apply_auto_cutoff(fig)

    if ~ishghandle(fig)
        return;
    end

    if isappdata(fig,'viewer_mode') && getappdata(fig,'viewer_mode')
        return;
    end

    if ~isappdata(fig,'n_peaks_all') || ~isappdata(fig,'opts')
        return;
    end

    n_peaks_all = getappdata(fig,'n_peaks_all');
    opts = getappdata(fig,'opts');

    if isempty(n_peaks_all)
        return;
    end

    mask_sizes = [];
    if isappdata(fig,'mask_sizes')
        mask_sizes = getappdata(fig,'mask_sizes');
    end

    drift_score = [];
    if isappdata(fig,'drift_score')
        drift_score = getappdata(fig,'drift_score');
    end
    
    score_quality_percentile = [];
    if isappdata(fig,'score_quality_percentile')
        score_quality_percentile = getappdata(fig,'score_quality_percentile');
    end
    
    if ~isempty(drift_score) && ...
       ~isempty(score_quality_percentile) && ...
       numel(drift_score) == numel(n_peaks_all) && ...
       numel(score_quality_percentile) == numel(n_peaks_all)
    
        good_by_drift = ...
            (drift_score <= opts.max_drift_score) | ...
            (score_quality_percentile >= opts.min_quality_percentile_for_high_drift);
    
    else
    
        good_by_drift = true(size(n_peaks_all));
    end

    good_by_peaks = n_peaks_all >= opts.min_n_peaks_cutoff;

    if ~isempty(mask_sizes) && numel(mask_sizes) == numel(n_peaks_all)
        good_by_mask = mask_sizes >= opts.min_mask_um2;
    else
        good_by_mask = true(size(n_peaks_all));
    end

    mask_connectivity_ratio = [];
    if isappdata(fig,'mask_connectivity_ratio')
        mask_connectivity_ratio = getappdata(fig,'mask_connectivity_ratio');
    end
    
    if ~isempty(mask_connectivity_ratio) && numel(mask_connectivity_ratio) == numel(n_peaks_all)
        good_by_connectivity = mask_connectivity_ratio >= opts.min_mask_connectivity;
    else
        good_by_connectivity = true(size(n_peaks_all));
    end

    selected_cells_from_cutoff = find( ...
        good_by_peaks & ...
        good_by_mask & ...
        good_by_connectivity & ...
        good_by_drift);

    setappdata(fig,'selected_cells_from_cutoff', selected_cells_from_cutoff);
    setappdata(fig,'cutoff_validated', true);
    setappdata(fig,'cutoff_locked', true);

    fprintf(['Cutoff auto : >= %d pics ET masque >= %.1f um^2 ' ...
        'ET connectivité >= %.2f ET drift <= %.2f sauf si quality >= %.0f/100.\n'], ...
        opts.min_n_peaks_cutoff, ...
        opts.min_mask_um2, ...
        opts.min_mask_connectivity, ...
        opts.max_drift_score, ...
        opts.min_quality_percentile_for_high_drift);
end

function validate_selection_filter(fig)

    if ~ishandle(fig)
        return;
    end

    if ~isappdata(fig,'cells_sorted_by_quality') || ~isappdata(fig,'n_peaks_all') || ~isappdata(fig,'opts')
        return;
    end

    if isappdata(fig,'viewer_mode') && getappdata(fig,'viewer_mode')
        return;
    end

    order_cells_all = getappdata(fig,'cells_sorted_by_quality');
    n_peaks_all = getappdata(fig,'n_peaks_all');
    opts = getappdata(fig,'opts');

    if isempty(order_cells_all) || isempty(n_peaks_all)
        return;
    end

    order_cells_all = order_cells_all(n_peaks_all(order_cells_all) > 0);
    setappdata(fig,'order_cells_all', order_cells_all);

    if isempty(order_cells_all)
        return;
    end

    if isappdata(fig,'cell_status')
        st = getappdata(fig,'cell_status');
    else
        st = zeros(max(order_cells_all),1);
    end

    min_n_peaks = opts.min_n_peaks_cutoff;
    min_mask_um2 = opts.min_mask_um2;

    mask_sizes = [];
    if isappdata(fig,'mask_sizes')
        mask_sizes = getappdata(fig,'mask_sizes');
    end
    
    good_by_peaks = n_peaks_all >= min_n_peaks;

    if ~isempty(mask_sizes) && numel(mask_sizes) == numel(n_peaks_all)
        good_by_mask = mask_sizes >= min_mask_um2;
    else
        good_by_mask = true(size(n_peaks_all));
    end

    mask_connectivity_ratio = [];
    if isappdata(fig,'mask_connectivity_ratio')
        mask_connectivity_ratio = getappdata(fig,'mask_connectivity_ratio');
    end
    
    if ~isempty(mask_connectivity_ratio) && numel(mask_connectivity_ratio) == numel(n_peaks_all)
        good_by_connectivity = mask_connectivity_ratio >= opts.min_mask_connectivity;
    else
        good_by_connectivity = true(size(n_peaks_all));
    end
    
    drift_score = [];
    if isappdata(fig,'drift_score')
        drift_score = getappdata(fig,'drift_score');
    end
    
    score_quality_percentile = [];
    if isappdata(fig,'score_quality_percentile')
        score_quality_percentile = getappdata(fig,'score_quality_percentile');
    end
    
    if ~isempty(drift_score) && ...
       ~isempty(score_quality_percentile) && ...
       numel(drift_score) == numel(n_peaks_all) && ...
       numel(score_quality_percentile) == numel(n_peaks_all)
    
        good_by_drift = ...
            (drift_score <= opts.max_drift_score) | ...
            (score_quality_percentile >= opts.min_quality_percentile_for_high_drift);
    
    else
    
        good_by_drift = true(size(n_peaks_all));
    end

    auto_keep = find( ...
        good_by_peaks & ...
        good_by_mask & ...
        good_by_connectivity & ...
        good_by_drift);

    manual_keep = find(st == +1);
    manual_excl = find(st == -1);

    kept_cells = unique([auto_keep(:); manual_keep(:)], 'stable');
    kept_cells = setdiff(kept_cells, manual_excl, 'stable');

    keep_mask = ismember(order_cells_all, kept_cells);
    order_cells = order_cells_all(keep_mask);

    if isempty(order_cells)
        warning('Aucune cellule retenue après validation.');
        return;
    end

    setappdata(fig,'order_cells', order_cells);
    setappdata(fig,'cutoff_validated', true);
    setappdata(fig,'cutoff_locked', true);
    setappdata(fig,'selected_cells_from_cutoff', auto_keep);

    setappdata(fig,'current_rank', 1);
    setappdata(fig,'nav_rank', 1);
    setappdata(fig,'cell_id', order_cells(1));

    sldr = findobj(fig,'Tag','sldr_nav_cell');
    if ~isempty(sldr) && isgraphics(sldr)
        n = numel(order_cells);
        set(sldr,'Min',1,'Max',max(1,n),'Value',1);
        step = 1/max(1,n-1);
        set(sldr,'SliderStep',[step min(1,10*step)]);
    end

    lbl = findobj(fig,'Tag','lbl_nav_cell');
    if ~isempty(lbl)
        lbl.String = sprintf('Navigation cellule (%d / %d)', 1, numel(order_cells));
    end

    setappdata(fig,'autotervals', []);
    setappdata(fig,'auto_peaks', []);

    if isappdata(fig,'seuil_detection_last')
        rmappdata(fig,'seuil_detection_last');
    end

    update_current_cell(fig, 1);
    
    fprintf(['Validation appliquée : %d cellules affichées ' ...
        '(%d pics min, masque >= %.1f um^2, connectivité >= %.2f, ' ...
        'drift <= %.2f sauf si quality >= %.0f/100).\n'], ...
        numel(order_cells), ...
        opts.min_n_peaks_cutoff, ...
        opts.min_mask_um2, ...
        opts.min_mask_connectivity, ...
        opts.max_drift_score, ...
        opts.min_quality_percentile_for_high_drift);
end

function refresh_selection_order(fig)

    if isappdata(fig,'cells_sorted_by_quality')
        order_cells_all = getappdata(fig,'cells_sorted_by_quality');

        if isappdata(fig,'n_peaks_all')
            n_peaks_all = getappdata(fig,'n_peaks_all');
            order_cells_all = order_cells_all(n_peaks_all(order_cells_all) > 0);
        end
    else
        order_cells_all = [];
    end

    setappdata(fig,'order_cells_all', order_cells_all);

    if isempty(order_cells_all)
        setappdata(fig,'order_cells', []);

        sldr = findobj(fig,'Tag','sldr_nav_cell');
        if ~isempty(sldr) && isgraphics(sldr)
            set(sldr,'Min',1,'Max',1,'Value',1,'SliderStep',[1 1]);
        end

        hEdit = findobj(fig,'Tag','edit_nav_rank');
        if ~isempty(hEdit) && isgraphics(hEdit(1))
            set(hEdit(1),'String','1');
        end

        lbl = findobj(fig,'Tag','lbl_nav_cell');
        if ~isempty(lbl)
            lbl.String = 'Navigation cellule (0 / 0)';
        end
        return;
    end

    order_cells = order_cells_all;
    setappdata(fig,'order_cells', order_cells);

    old_cid = [];
    if isappdata(fig,'cell_id')
        old_cid = getappdata(fig,'cell_id');
    end

    idx = 1;
    if ~isempty(old_cid)
        k = find(order_cells == old_cid, 1);
        if ~isempty(k)
            idx = k;
        end
    end
    idx = max(1, min(numel(order_cells), idx));

    setappdata(fig,'current_rank', idx);
    setappdata(fig,'nav_rank', idx);
    setappdata(fig,'cell_id', order_cells(idx));

    viewer_mode = isappdata(fig,'viewer_mode') && getappdata(fig,'viewer_mode');
    locked = isappdata(fig,'cutoff_locked') && getappdata(fig,'cutoff_locked');

    % Tant que le cutoff n'est pas verrouillé, il suit la navigation
    if ~viewer_mode && ~locked
        setappdata(fig,'cutoff_rank', idx);
    end

    sldr = findobj(fig,'Tag','sldr_nav_cell');
    if ~isempty(sldr) && isgraphics(sldr)
        n = numel(order_cells);
        set(sldr,'Min',1,'Max',n,'Value',idx);
        step = 1/max(1,n-1);
        set(sldr,'SliderStep',[step min(1,10*step)]);
    end

    hEdit = findobj(fig,'Tag','edit_nav_rank');
    if ~isempty(hEdit) && isgraphics(hEdit(1))
        if ~viewer_mode && ~locked
            set(hEdit(1), 'String', num2str(idx));
        else
            cutoff_rank = getappdata(fig,'cutoff_rank');
            set(hEdit(1), 'String', num2str(cutoff_rank));
        end
    end

    lbl = findobj(fig,'Tag','lbl_nav_cell');
    if ~isempty(lbl)
        lbl.String = sprintf('Navigation cellule (%d / %d)', idx, numel(order_cells));
    end

    auto_detect_and_add(fig);
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

%% ===================== USER SELECTION =====================

function keep_cell(fig)

    if isappdata(fig,'viewer_mode') && getappdata(fig,'viewer_mode')
        return;
    end

    if ~isappdata(fig,'cell_id') || ~isappdata(fig,'cell_status')
        return;
    end

    cid = getappdata(fig,'cell_id');
    st  = getappdata(fig,'cell_status');

    if isempty(cid) || cid < 1 || cid > numel(st)
        return;
    end

    st(cid) = +1;
    setappdata(fig,'cell_status', st);

    auto_detect_and_add(fig);
    drawnow;
    pause(0.01);
end

function exclude_cell(fig)

    if isappdata(fig,'viewer_mode') && getappdata(fig,'viewer_mode')
        return;
    end

    if ~isappdata(fig,'cell_id') || ~isappdata(fig,'cell_status')
        return;
    end

    cid = getappdata(fig,'cell_id');
    st  = getappdata(fig,'cell_status');

    if isempty(cid) || cid < 1 || cid > numel(st)
        return;
    end

    st(cid) = -1;
    setappdata(fig,'cell_status', st);

    auto_detect_and_add(fig);
    drawnow;
    pause(0.01);
end

function finalize_and_close(fig, synchronous_frames)

    viewer_mode = isappdata(fig,'viewer_mode') && getappdata(fig,'viewer_mode');

    if viewer_mode
        
        DF_raw = getappdata(fig,'DF_raw');
        DF_sg = getappdata(fig,'DF_sg');
        drift_score = getappdata(fig,'drift_score');
        F0 = getappdata(fig,'F0');

        Raster = getappdata(fig,'Raster_saved');
        Acttmp2 = getappdata(fig,'Acttmp2_saved');
        thresholds = getappdata(fig,'thresholds_saved');
        valid_cells = getappdata(fig,'valid_cells_saved');

        if isempty(valid_cells)
            valid_cells = (1:size(DF_sg,1)).';
        end

        setappdata(fig,'last_save_outputs', struct( ...
            'invalid_cells', [], ...
            'valid_cells', valid_cells, ...
            'orig2new', [], ...
            'DF_raw', DF_raw, ...
            'DF_sg', DF_sg, ...
            'drift_score', drift_score, ...
            'F0', F0, ...
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

    if isappdata(fig,'order_cells_all') && isappdata(fig,'order_cells')
        order_cells_all = getappdata(fig,'order_cells_all');
        order_cells     = getappdata(fig,'order_cells');
    
        if numel(order_cells) == numel(order_cells_all)
            validate_selection_filter(fig);
        end
    end

    [invalid_cells, valid_cells, DF, F0, Raster, Acttmp2, MAct, thresholds, opts, summary] = ...
        save_peak_matrix(fig, synchronous_frames);

    try
        if isappdata(fig,'gcamp_output_folder')
            outdir_preview = getappdata(fig,'gcamp_output_folder');
        else
            outdir_preview = '';
        end
    
        create_random_peak_preview(valid_cells, DF, Acttmp2, thresholds, outdir_preview);
    catch ME
        warning('Impossible de créer la figure preview des pics : %s', ME.message);
    end

    orig2new = nan(max([valid_cells(:); 1]),1);
    if ~isempty(valid_cells)
        orig2new(valid_cells) = 1:numel(valid_cells);
    end

    if iscell(Acttmp2) && size(Acttmp2,2) > 1
        Acttmp2 = reshape(Acttmp2, [], 1);
    end

    setappdata(fig,'last_save_outputs', struct( ...
        'invalid_cells', invalid_cells, ...
        'valid_cells', valid_cells, ...
        'orig2new', orig2new, ...
        'DF_sg', DF, ...
        'DF_raw', getappdata(fig,'DF_raw'), ...
        'drift_score', getappdata(fig,'drift_score'), ...
        'F0', F0, ...
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
%% ===================== DISPLAY =====================
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

    is_blue_cell = false;
    if isappdata(fig,'blue_indices')
        blue_indices = getappdata(fig,'blue_indices');

        if ~isempty(blue_indices)
            blue_indices = blue_indices(:);
            blue_indices = blue_indices(isfinite(blue_indices));
            is_blue_cell = any(round(blue_indices) == round(cell_id));
        end
    end

    if is_blue_cell
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

        n_peaks_all = [];
        if isappdata(fig,'n_peaks_all')
            n_peaks_all = getappdata(fig,'n_peaks_all');
        end

        cutoff_validated = isappdata(fig,'cutoff_validated') && getappdata(fig,'cutoff_validated');

        if isappdata(fig,'cell_status')

            st = getappdata(fig,'cell_status');

            if cell_id >= 1 && cell_id <= numel(st)

                if st(cell_id) == -1

                    if ~isempty(n_peaks_all) && ...
                       cell_id <= numel(n_peaks_all) && ...
                       n_peaks_all(cell_id) == 0

                        label_txt   = 'AUTO BAD (0 pics)';
                        label_color = [0.6 0.6 0.6];
                    else
                        label_txt   = 'BAD MANUEL';
                        label_color = [0.85 0.1 0.1];
                    end

                elseif st(cell_id) == +1

                    label_txt   = 'GOOD MANUEL';
                    label_color = [0.1 0.6 0.1];

                else

                   if cutoff_validated && ~isempty(n_peaks_all) && isappdata(fig,'opts')

                        opts = getappdata(fig,'opts');
                        min_n_peaks = opts.min_n_peaks_cutoff;
                    
                        if cell_id <= numel(n_peaks_all)
                    
                            cond_peaks = n_peaks_all(cell_id) >= min_n_peaks;
                    
                            cond_mask = true;
                            if isappdata(fig,'mask_sizes')
                                mask_sizes = getappdata(fig,'mask_sizes');
                    
                                if cell_id <= numel(mask_sizes)
                                    cond_mask = isfinite(mask_sizes(cell_id)) && ...
                                        (mask_sizes(cell_id) >= opts.min_mask_um2);
                                end
                            end
                    
                            cond_connectivity = true;
                            if isappdata(fig,'mask_connectivity_ratio')
                                mask_connectivity_ratio = getappdata(fig,'mask_connectivity_ratio');
                    
                                if cell_id <= numel(mask_connectivity_ratio)
                                    cond_connectivity = isfinite(mask_connectivity_ratio(cell_id)) && ...
                                        (mask_connectivity_ratio(cell_id) >= opts.min_mask_connectivity);
                                end
                            end

                            cond_drift = true;
                            drift_score = [];
                            if isappdata(fig,'drift_score')
                                drift_score = getappdata(fig,'drift_score');
                            end
                            
                            score_quality_percentile = [];
                            if isappdata(fig,'score_quality_percentile')
                                score_quality_percentile = getappdata(fig,'score_quality_percentile');
                            end
                            
                            if ~isempty(drift_score) && ...
                               ~isempty(score_quality_percentile) && ...
                               cell_id <= numel(drift_score) && ...
                               cell_id <= numel(score_quality_percentile) && ...
                               isfinite(drift_score(cell_id)) && ...
                               isfinite(score_quality_percentile(cell_id))
                            
                                cond_drift = ...
                                    (drift_score(cell_id) <= opts.max_drift_score) || ...
                                    (score_quality_percentile(cell_id) >= opts.min_quality_percentile_for_high_drift);
                            end
                    
                            if cond_peaks && cond_mask && cond_connectivity && cond_drift
                                label_txt   = 'GOOD (peaks+mask+conn+drift)';
                                label_color = [0.1 0.6 0.1];
                            else
                                label_txt   = 'BAD (peaks/mask/conn)';
                                label_color = [0.85 0.1 0.1];
                            end
                        end
                   end
                end

                if ~isempty(label_txt)
                    text(ax, 0.02, 0.95, label_txt, ...
                        'Units','normalized', ...
                        'Color',label_color, ...
                        'FontWeight','bold', ...
                        'FontSize',12, ...
                        'VerticalAlignment','top', ...
                        'BackgroundColor',[1 1 1 0.6], ...
                        'Margin',4);
                end
            end
        end
    end

    if isappdata(fig,'drift_score')

        drift_score = getappdata(fig,'drift_score');
    
        if ~isempty(drift_score) && ...
           cell_id >= 1 && ...
           cell_id <= numel(drift_score) && ...
           isfinite(drift_score(cell_id))
    
            text(ax, 0.02, 0.84, ...
                sprintf('Drift = %.2f', drift_score(cell_id)), ...
                'Units','normalized', ...
                'Color',[0.15 0.15 0.15], ...
                'FontWeight','bold', ...
                'FontSize',11, ...
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

%% ===================== SLIDERS / PARAMS =====================

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

        setappdata(fig,'autotervals', []);

        if isappdata(fig,'current_rank')
            update_current_cell(fig, getappdata(fig,'current_rank'));
        else
            update_current_cell(fig, 1);
        end

        drawnow;
        return;
    end

    if ismember(field, {'window_size_s','savgol_win_ms'})

        F = getappdata(fig,'F_raw');

        if isappdata(fig,'bad_frames')
            bad_frames = getappdata(fig,'bad_frames');
        else
            bad_frames = [];
        end
        
        [DF_raw, F0] = F_processing(F, bad_frames, fs, opts.window_size);
        
        DF_sg = savgol_transform(DF_raw, opts);
        noise_est = estimate_noise(DF_raw);
        
        setappdata(fig,'F0', F0);
        setappdata(fig,'DF_sg', DF_sg);
        setappdata(fig,'DF_raw', DF_raw);
        setappdata(fig,'noise_est', noise_est);
        setappdata(fig,'drift_score', drift_score);
        
        [~, SNR, score, cells_sorted_by_quality, ~, ~, ~] = ...
            compute_snr_quality(DF_sg, noise_est, opts, bad_frames);
        
        setappdata(fig,'SNR', SNR);
        setappdata(fig,'score_quality', score);

        score_quality_percentile = nan(size(score));

        valid_score = isfinite(score);
        [~, order_score] = sort(score(valid_score), 'ascend');
        
        tmp = nan(sum(valid_score),1);
        tmp(order_score) = linspace(0,100,sum(valid_score));
        
        score_quality_percentile(valid_score) = tmp;
        
        setappdata(fig,'score_quality_percentile', score_quality_percentile);

        setappdata(fig,'cells_sorted_by_quality', cells_sorted_by_quality);
    end

    setappdata(fig,'autotervals', []);
    setappdata(fig,'auto_peaks', []);

    if isappdata(fig,'seuil_detection_last')
        rmappdata(fig,'seuil_detection_last');
    end

    recompute_n_peaks_all(fig);
    apply_auto_cutoff(fig);
    refresh_selection_order(fig);

    rank = getappdata(fig,'current_rank');
    update_current_cell(fig, rank);

    drawnow;
end
%% ===================== UTILITIES =====================
function create_random_peak_preview(valid_cells, DF, Acttmp2, thresholds, outdir_preview)
% Crée une figure avec jusqu'à 10 cellules tirées au hasard parmi
% les cellules gardées, affiche leurs traces + pics détectés,
% et sauvegarde automatiquement un PNG si absent.

    if nargin < 4
        thresholds = [];
    end
    if nargin < 5
        outdir_preview = '';
    end

    if isempty(valid_cells) || isempty(DF)
        warning('Aucune cellule valide à afficher dans la preview.');
        return;
    end

    nCellsFinal = size(DF, 1);
    if nCellsFinal == 0
        warning('DF final vide, preview non générée.');
        return;
    end

    % ----------------------------
    % Nom du fichier de sauvegarde
    % ----------------------------
    png_path = '';
    if ~isempty(outdir_preview) && (ischar(outdir_preview) || isstring(outdir_preview))
        outdir_preview = char(outdir_preview);

        if ~exist(outdir_preview, 'dir')
            mkdir(outdir_preview);
        end

        png_path = fullfile(outdir_preview, 'random_peak_preview.png');

        % if exist(png_path, 'file') == 2
        %     fprintf('Preview PNG déjà existante, pas de nouvelle sauvegarde : %s\n', png_path);
        %     return;
        % end
    end

    % ----------------------------
    % Tirage aléatoire
    % ----------------------------
    nShow = min(10, nCellsFinal);
    rng('shuffle');
    idx_show = randperm(nCellsFinal, nShow);

    figPrev = figure( ...
        'Name', sprintf('Preview aléatoire de %d traces avec pics', nShow), ...
        'NumberTitle', 'off', ...
        'Color', 'w', ...
        'Position', [150 80 1200 900], ...
        'Visible', 'on');

    tiledlayout(figPrev, 5, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

    for k = 1:nShow
        ii = idx_show(k);
        cid_orig = valid_cells(ii);
        x = DF(ii, :);
        t = 1:numel(x);

        nexttile;
        hold on;
        box off;

        set(gca, 'LineWidth', 0.8);
        set(gca, 'TickDir', 'out');
        
        plot(t, x, 'k-', 'LineWidth', 1);

        pk = [];
        if iscell(Acttmp2) && numel(Acttmp2) >= ii && ~isempty(Acttmp2{ii})
            pk = Acttmp2{ii};
            pk = pk(:)';
            pk = pk(isfinite(pk) & pk >= 1 & pk <= numel(x));
        end

        if ~isempty(pk)
            plot(pk, x(pk), '*', ...
            'Color', [0.85 0.1 0.1], ...
            'MarkerSize', 3.5, ...
            'LineWidth', 0.7);
        end

        if ~isempty(thresholds) && numel(thresholds) >= ii && isfinite(thresholds(ii))
            yline(thresholds(ii), '--', 'LineWidth', 1);
        end

        title(sprintf('Cellule orig %d | final %d | n=%d pics', ...
            cid_orig, ii, numel(pk)), ...
            'FontWeight', 'bold', 'Interpreter', 'none');

        xlabel('Frames');
        ylabel('\DeltaF/F');
        xlim([1 numel(x)]);

        hold off;
    end

    % ----------------------------
    % Sauvegarde PNG si demandé
    % ----------------------------
    if ~isempty(png_path)
        try
            exportgraphics(figPrev, png_path, 'Resolution', 200);
            fprintf('Preview PNG sauvegardée : %s\n', png_path);
        catch
            saveas(figPrev, png_path);
            fprintf('Preview PNG sauvegardée (saveas) : %s\n', png_path);
        end

        if ishghandle(figPrev)
            close(figPrev);
        end
    end
end

