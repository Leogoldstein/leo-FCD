function [F0, noise_est, SNR, valid_cells, DF_sg, Raster, Acttmp2, StartEnd, MAct, thresholds, focus_segs, opts, has_new_outputs] = ...
    peak_detection_tuner(F, fs, synchronous_frames, varargin)
% GUI CalTrig — interactive tuning and saving of Ca²⁺ transient detection
%
% Inputs:
%   F   : raw fluorescence (n_cells x T)
%   fs  : sampling rate (Hz)
%   synchronous_frames : fenêtre pour activité synchrone
%
% Outputs:
%   DF_sg, F0, noise_est, SNR : preprocessing
%   Raster, Acttmp2, StartEnd, MAct, thresholds : détection de pics

    % ---- Options détection (valeurs initiales) ----
    opts = struct( ...
        'window_size', 800, ... 
        'savgol_win', 9, ...
        'savgol_poly', 3, ...
        'min_width_fr', 6, ...
        'prominence_factor', 0.8, ...
        'refrac_fr', 3, ...
        'min_n_peaks_cutoff', 10, ...
        'min_mask_pixels', 10 ...
    );

    % ---- Inputs optionnels ----
    iscell_in = [];
    stat_in   = [];
    speed     = [];
    deviation = [];
    bad_frames = [];
    focus_segs = [];
    gcamp_TSeries_path = '';
    gcamp_output_folder = '';
    meanImg = [];
    ops = [];
    meta_tbl = [];
    viewer_mode = false;
    cell_type = '';
    masks = [];
    blue_indices = [];

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

                case 'cell_type'
                    cell_type = char(val);

                case 'ops'
                    ops = val;

                case 'animal_group'
                    animal_group = val; %#ok<NASGU>

                case 'ages_group'
                    ages_group = val; %#ok<NASGU>

                case 'iscell'
                    iscell_in = val;

                case 'stat'
                    stat_in = val;

                 case 'masks'
                    masks = val;

                case 'blue_indices'
                    blue_indices = val;

                case 'meanImg'
                    meanImg = val;

                case 'gcamp_TSeries_path'
                    gcamp_TSeries_path = val;

                case 'speed'
                    speed = val;

                case 'meta_tbl'
                    meta_tbl = val;
                 
                case 'gcamp_output_folder'
                    gcamp_output_folder = val;
            end
        end
    end

    % ---- Motion correction / bad frames ----
    if ~isempty(speed)
        [deviation, bad_frames, ~, ~, F] = ...
            motion_correction_substraction(F, ops, speed);

        deviation  = deviation(:).';
        bad_frames = bad_frames(:).';

        bad_segs = badframes_to_segments(bad_frames, size(F,2));
        segTable = sort_segments_by_deviation(bad_segs, deviation);
        assignin('base', 'segTable', segTable);

        user_focus_segs = [];
        % [user_focus_segs, user_focus_frames] = enter_observed_deviations(gcamp_TSeries_path, size(F,2));

        if ~isempty(user_focus_segs)
            focus_segs = user_focus_segs;
        else
            focus_segs = bad_segs;
        end
    end

    % ---- Prétraitement ----
    window_size = opts.window_size;
    [Fdetrend, F0] = F_processing(F, bad_frames, fs, window_size);
    noise_est = estimate_noise(Fdetrend);
    DF_sg = DF_processing(Fdetrend, opts);

    % ---- Qualité / SNR ----
    [~, SNR, ~, cells_sorted_by_quality, ~, ~, ~] = ...
        compute_snr_quality(DF_sg, noise_est, opts, bad_frames);

    % ---- Titre fenêtre ----
    winTitle = '';
    
    if viewer_mode
        winTitle = '[VIEWER MODE]';
    elseif ~isempty(gcamp_TSeries_path)
        planePath = fileparts(gcamp_TSeries_path);
        nCells = size(F,1);
        winTitle = sprintf('%s | nCells=%d', planePath, nCells);
    else
        winTitle = sprintf('nCells=%d', size(F,1));
    end
    
    if ~isempty(cell_type)
        if isempty(winTitle)
            winTitle = sprintf('cell type: %s', cell_type);
        else
            winTitle = sprintf('%s | %s', winTitle, cell_type);
        end
    end
    
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
        'Tag','lbl_quality_thr', ...
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
        'Tag','sldr_quality_thr', ...
        'Callback', @(src,~) update_quality_threshold(fig, round(get(src,'Value'))));
    
    % ---- Cutoff ----
    uicontrol('Parent',ctrl_panel,'Style','text', ...
        'String','Cutoff', ...
        'Units','normalized', ...
        'Position',[0.05 0.315 0.50 0.03], ...
        'HorizontalAlignment','left', ...
        'BackgroundColor',[.97 .97 .98], ...
        'FontWeight','bold');
    
    uicontrol('Parent',ctrl_panel,'Style','edit', ...
        'String', '1', ...
        'Units','normalized', ...
        'Position',[0.58 0.305 0.17 0.045], ...
        'Tag','edit_nav_rank', ...
        'BackgroundColor','w', ...
        'Callback', @(src,~) goto_navigation_index(fig, src));
    
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
        set(findobj(ctrl_panel,'String','Définir cutoff'),    'Enable','off');
        set(findobj(ctrl_panel,'String','Valider sélection'), 'Enable','off');
        set(findobj(ctrl_panel,'String','Garder cellule'),    'Enable','off');
        set(findobj(ctrl_panel,'String','Exclure cellule'),   'Enable','off');
    end

    % ---- Contrôles détection ----
    make_slider(ctrl_panel,fig,'Window size (fr)','window_size',round(fs*5),round(fs*300),opts.window_size,[0.05 0.76 0.90 0.06]);
    make_slider(ctrl_panel,fig,'Largeur min (fr)','min_width_fr',0,50,opts.min_width_fr,[0.05 0.68 0.90 0.06]);
    make_slider(ctrl_panel,fig,'Prominence','prominence_factor',0,3,opts.prominence_factor,[0.05 0.60 0.90 0.06]);
    make_slider(ctrl_panel,fig,'Réfractaire (fr)','refrac_fr',0,10,opts.refrac_fr,[0.05 0.52 0.90 0.06]);
    make_slider(ctrl_panel,fig,'SavGol window','savgol_win',3,51,opts.savgol_win,[0.05 0.44 0.90 0.06]);

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

    % ---- ROI ----
    axROI = axes('Parent',fig,'Position',[0.28 0.08 0.30 0.32]);
    box(axROI,'on');
    title(axROI,'ROI (zoom)');
    axis(axROI,'image');

    % ---- Histogramme ----
    axH = axes('Parent',fig,'Position',[0.62 0.08 0.35 0.32]);
    box(axH,'on');
    title(axH,'# pics / cellule');
    xlabel(axH,'Nombre de pics');
    ylabel(axH,'Nombre de cellules');

   % ---- Appdata ----
    setappdata(fig,'fs',fs);
    setappdata(fig,'F_raw',F);
    setappdata(fig,'DF_sg',DF_sg);
    setappdata(fig,'F0',F0);
    setappdata(fig,'noise_est',noise_est);
    setappdata(fig,'SNR',SNR);
    setappdata(fig,'opts',opts);
    
    setappdata(fig,'ax1',ax1);
    setappdata(fig,'axF0',axF0);
    setappdata(fig,'axDev',axDev);
    setappdata(fig,'axROI',axROI);
    setappdata(fig,'axH',axH);
    
    setappdata(fig,'deviation', deviation);
    setappdata(fig,'bad_frames', bad_frames);
    setappdata(fig,'focus_segs', focus_segs);
    
    setappdata(fig,'cells_sorted_by_quality', cells_sorted_by_quality);
    setappdata(fig,'iscell', iscell_in);
    setappdata(fig,'stat', stat_in);
    setappdata(fig,'meanImg', meanImg);
    setappdata(fig,'meta_tbl', meta_tbl);
    setappdata(fig,'viewer_mode', viewer_mode);
    setappdata(fig,'blue_indices', blue_indices);
    
    % cell_status: 0 undecided, +1 keep, -1 exclude
    setappdata(fig,'cell_status', zeros(size(F,1),1));

    setappdata(fig,'gcamp_output_folder', gcamp_output_folder);

    setappdata(fig,'masks', masks);
    
    mask_sizes = [];

    if ~isempty(masks) && (isnumeric(masks) || islogical(masks)) && ndims(masks) >= 3
        nCells_masks = size(masks,1);
        mask_sizes = zeros(nCells_masks,1);
    
        for i = 1:nCells_masks
            m = squeeze(masks(i,:,:));
            if ~isempty(m)
                mask_sizes(i) = sum(m(:) > 0);
            end
        end
    end
    
    setappdata(fig,'mask_sizes', mask_sizes);
    
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

    if ~isempty(focus_segs)
        hBad1 = create_badframe_patch(ax1, focus_segs);
        setappdata(fig,'hBadPatch_ax1', hBad1);
    
        hBadF0 = create_badframe_patch(axF0, focus_segs);
        setappdata(fig,'hBadPatch_axF0', hBadF0);
    
        hBadDev = create_badframe_patch(axDev, focus_segs);
        setappdata(fig,'hBadPatch_axDev', hBadDev);
    end
    
    linkaxes([ax1 axF0 axDev],'x');

    % ---- Recompute pics ----
    recompute_n_peaks_all(fig);
    apply_auto_cutoff(fig);

    n_peaks_all = getappdata(fig,'n_peaks_all');
    cell_status = getappdata(fig,'cell_status');
    zero_peak_cells = (n_peaks_all == 0);
    cell_status(zero_peak_cells) = -1;
    setappdata(fig,'cell_status', cell_status);

    refresh_selection_order(fig);
    update_quality_threshold(fig, 1);
    drawnow;

    uiwait(fig);
    has_new_outputs = false;

    % ---- Sorties ----
    if ishghandle(fig) && isappdata(fig,'last_save_outputs')
        out = getappdata(fig,'last_save_outputs');

        has_new_outputs = true;
        valid_cells = out.valid_cells;
        DF_sg       = out.DF_sg;
        F0          = out.F0;
        Raster      = out.Raster;
        Acttmp2     = out.Acttmp2;
        StartEnd    = out.StartEnd;
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
        StartEnd   = repmat({[]}, size(F,1),1);
        MAct       = [];
        thresholds = nan(size(F,1),1);
        valid_cells = [];
        DF_sg = [];
        F0 = [];
    end

    if ishghandle(fig)
        delete(fig);
    end
end

%% ===================== PIPELINE CORE =====================

function DF_sg = DF_processing(Fdetrend, opts)

    sg_win  = opts.savgol_win;
    sg_poly = opts.savgol_poly;

    [NCell, Nz] = size(Fdetrend);

    DF_sg          = nan(NCell, Nz);
    DF_plate       = nan(NCell, Nz); %#ok<NASGU>

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
        sig = Fdetrend(n,:);

        if sum(isfinite(sig)) >= sgN
            try
                DF_sg(n,:) = sgolayfilt(sig, sg_poly, sgN);
            catch
                DF_sg(n,:) = sig;
            end
        else
            DF_sg(n,:) = sig;
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
        'locs_raw', [], ...
        'intervals_raw', zeros(0,2), ...
        'locs_merged', [], ...
        'intervals_merged', zeros(0,2));

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

    x_det = x;
    x_det(bad_mask) = -Inf;
    
    seuil_detection = 2.33 * sigma;
    %seuil_detection = 3.09 * sigma;
    if ~isfinite(seuil_detection) || seuil_detection <= 0
        seuil_detection = 0;
    end
    out.threshold = seuil_detection;

    minW = max(1, round(opts.min_width_fr));
    mpd  = max(1, round(opts.refrac_fr));
    prom = seuil_detection * opts.prominence_factor;

    if ~isfinite(prom) || prom < 0
        prom = 0;
    end

    x_valid = x_det(isfinite(x_det));
    if isempty(x_valid)
        return;
    end

    if max(x_valid) <= seuil_detection
        return;
    end

    try
        [~, locs] = findpeaks(x_det, ...
            'MinPeakHeight', seuil_detection, ...
            'MinPeakProminence', prom, ...
            'MinPeakDistance', mpd);
    catch
        locs = [];
    end

    if isempty(locs)
        return;
    end

    locs = locs(:);
    locs = locs(locs >= 1 & locs <= Nx);
    locs = locs(~bad_mask(locs));

    out.locs_raw = locs;

    if isempty(locs)
        return;
    end

    intervals = zeros(numel(locs), 2);
    keep_interval = true(numel(locs),1);

    local_win = 120;
    baseline_margin = 0.5;

    for i = 1:numel(locs)
        pk = locs(i);

        left_win = max(1, pk - local_win);
        local_segment = x(left_win:pk);
        local_segment = local_segment(isfinite(local_segment));

        if isempty(local_segment)
            keep_interval(i) = false;
            continue;
        end

        baseline_local_i = prctile(local_segment, 10);
        noise_local = std(local_segment, 'omitnan');
        if ~isfinite(noise_local)
            noise_local = 0;
        end

        thr_event = baseline_local_i + baseline_margin * noise_local;

        a = pk;
        while a > 1 && isfinite(x(a)) && x(a) > thr_event && ~bad_mask(a)
            a = a - 1;
        end
        if bad_mask(a) || ~isfinite(x(a)) || x(a) <= thr_event
            a = min(pk, a + 1);
        end

        b = pk;
        while b < Nx && isfinite(x(b)) && x(b) > thr_event && ~bad_mask(b)
            b = b + 1;
        end
        if bad_mask(b) || ~isfinite(x(b)) || x(b) <= thr_event
            b = max(pk, b - 1);
        end

        if (b - a + 1) < minW
            d = ceil((minW - (b - a + 1))/2);
            a = max(1, a - d);
            b = min(Nx, b + d);
        end

        if a > b || any(bad_mask(a:b))
            keep_interval(i) = false;
        else
            intervals(i,:) = [a b];
        end
    end

    locs = locs(keep_interval);
    intervals = intervals(keep_interval,:);

    out.intervals_raw = intervals;

    if isempty(locs) || isempty(intervals)
        return;
    end

    intervals = sortrows(intervals, 1);
    merged = [];
    cur = intervals(1,:);
    gap = max(0, round(opts.refrac_fr));

    for i = 2:size(intervals,1)
        if intervals(i,1) <= cur(2) + gap
            cur(2) = max(cur(2), intervals(i,2));
        else
            merged = [merged; cur]; %#ok<AGROW>
            cur = intervals(i,:);
        end
    end
    merged = [merged; cur];

    locs_merged = [];
    for r = 1:size(merged,1)
        in_interval = locs(locs >= merged(r,1) & locs <= merged(r,2));
        if ~isempty(in_interval)
            [~, idx_max] = max(x(in_interval));
            pk = in_interval(idx_max);

            if ~bad_mask(pk) && isfinite(x(pk)) && x(pk) >= seuil_detection
                locs_merged(end+1,1) = pk; %#ok<AGROW>
            end
        end
    end

    out.locs_merged = locs_merged;
    out.intervals_merged = merged;
end

function [A, SNR, score, cells_sorted_by_quality, quality_min, quality_max, quality_thr0] = ...
    compute_snr_quality(DF_sg, noise_est, opts, bad_frames)
% compute_snr_quality
% Classe les cellules selon une amplitude robuste des pics détectés
% directement avec detect_peaks_cell_core.
%
% Inputs:
%   DF_sg      : [NCell x Nz]
%   noise_est  : [NCell x 1]
%   opts       : struct de détection
%   bad_frames : indices/logical des frames à exclure (optionnel)
%
% Outputs:
%   A                     : amplitude robuste des pics par cellule
%   SNR                   : A / bruit
%   score                 : score final
%   cells_sorted_by_quality : ids triés du pire au meilleur
%   quality_min/max/thr0  : bornes UI

    if nargin < 3 || isempty(opts)
        error('compute_snr_quality requires DF_sg, noise_est, and opts.');
    end

    if nargin < 4
        bad_frames = [];
    end

    if isempty(DF_sg) || ndims(DF_sg) ~= 2
        error('DF_sg must be a 2D matrix [NCell x Nz].');
    end

    [NCell, ~] = size(DF_sg);

    noise_est = noise_est(:);
    if numel(noise_est) ~= NCell
        error('noise_est must have one value per cell (%d expected).', NCell);
    end

    noise_est(~isfinite(noise_est) | noise_est <= 0) = eps;

    A   = zeros(NCell,1);
    SNR = zeros(NCell,1);
    score = zeros(NCell,1);

    for cid = 1:NCell
        x = DF_sg(cid,:).';
        sigma = noise_est(cid);

        if isempty(x) || all(~isfinite(x))
            A(cid) = 0;
            SNR(cid) = 0;
            score(cid) = 0;
            continue;
        end
        out = detect_peaks_cell_core(x, sigma, opts, bad_frames);

        if isempty(out.locs_merged)
            A(cid) = 0;
            SNR(cid) = 0;
            score(cid) = 0;
            continue;
        end

        peak_vals = x(out.locs_merged);
        peak_vals = peak_vals(isfinite(peak_vals));

        if isempty(peak_vals)
            A(cid) = 0;
            SNR(cid) = 0;
            score(cid) = 0;
            continue;
        end

        % amplitude robuste des événements détectés
        A(cid) = median(peak_vals);

        if ~isfinite(A(cid)) || A(cid) < 0
            A(cid) = 0;
        end

        SNR(cid) = A(cid) / sigma;
        if ~isfinite(SNR(cid)) || SNR(cid) < 0
            SNR(cid) = 0;
        end

        % score final
        % on peut ensuite enrichir ce score avec d'autres critères si besoin
        score(cid) = SNR(cid);
    end

    [~, cells_sorted_by_quality] = sort(score, 'ascend');
    cells_sorted_by_quality = cells_sorted_by_quality(:);

    quality_min  = 1;
    quality_max  = NCell;
    quality_thr0 = max(1, round(0.5 * NCell));

    quality_min  = double(quality_min);
    quality_max  = double(quality_max);
    quality_thr0 = double(quality_thr0);
end

function noise_est = estimate_noise(Fdetrend)

    [NCell, ~] = size(Fdetrend);
    noise_est = nan(NCell, 1);

    for n = 1:NCell
        d = diff(Fdetrend(n,:));
        d = d(isfinite(d));

        if ~isempty(d)
            ne = 1.4826 * mad(d, 1) / sqrt(2);
        else
            ne = NaN;
        end

        if ~isfinite(ne) || ne <= 0
            ne = std(Fdetrend(n,:), 'omitnan');
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

    if ~isappdata(fig,'DF_sg') || ~isappdata(fig,'cell_id') || ...
       ~isappdata(fig,'opts')  || ~isappdata(fig,'noise_est')
        return;
    end

    DF_sg     = getappdata(fig,'DF_sg');
    cid       = getappdata(fig,'cell_id');
    opts      = getappdata(fig,'opts');
    noise_est = getappdata(fig,'noise_est');

    if isappdata(fig,'bad_frames')
        bad_frames = getappdata(fig,'bad_frames');
    else
        bad_frames = [];
    end

    if isempty(cid) || ~isscalar(cid) || ~isfinite(cid)
        return;
    end
    cid = round(cid);

    if cid < 1 || cid > size(DF_sg,1)
        return;
    end

    x = DF_sg(cid,:).';

    out = detect_peaks_cell_core(x, noise_est(cid), opts, bad_frames);

    setappdata(fig,'auto_intervals', out.intervals_merged);
    setappdata(fig,'auto_peaks', out.locs_merged);
    setappdata(fig,'seuil_detection_last', out.threshold);

    refresh_data(fig);
end

function recompute_n_peaks_all(fig)
    DF_sg     = getappdata(fig,'DF_sg');
    noise_est = getappdata(fig,'noise_est');
    opts      = getappdata(fig,'opts');

    nCells = size(DF_sg,1);
    n_peaks_all = zeros(nCells,1);

    if isappdata(fig,'bad_frames')
        bad_frames = getappdata(fig,'bad_frames');
    else
        bad_frames = [];
    end

    for cid = 1:nCells
        x = DF_sg(cid,:).';
        sigma = noise_est(cid);

        if ~isfinite(sigma) || sigma <= 0
            sigma = std(x,'omitnan');
        end
        if ~isfinite(sigma) || sigma <= 0
            sigma = eps;
        end

        out = detect_peaks_cell_core(x, sigma, opts, bad_frames);
        n_peaks_all(cid) = numel(out.locs_merged);
    end

    setappdata(fig,'n_peaks_all', n_peaks_all);
end

function [invalid_cells, valid_cells, DF_sg, F0, Raster, Acttmp2, StartEnd, MAct, thresholds, opts, summary] = ...
    save_peak_matrix(fig, synchronous_frames)

    DF_sg     = getappdata(fig,'DF_sg');
    opts      = getappdata(fig,'opts');
    noise_est = getappdata(fig,'noise_est');
    F0        = getappdata(fig,'F0');

    if isappdata(fig,'bad_frames')
        bad_frames = getappdata(fig,'bad_frames');
    else
        bad_frames = [];
    end

    nCells = size(DF_sg,1);
    Nz     = size(DF_sg,2);

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
    StartEnd   = cell(nCells,1);

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
            good_by_mask = mask_sizes >= opts.min_mask_pixels;
        else
            good_by_mask = true(size(n_peaks_all));
        end
        
        selected_cells_from_cutoff = find(good_by_peaks & good_by_mask);
    else
        selected_cells_from_cutoff = [];
    end

    n_kept = 0;

    for cid = 1:nCells

        if cell_status(cid) == -1
            Acttmp2{cid} = [];
            thresholds(cid) = NaN;
            Raster(cid,:) = false;
            StartEnd{cid} = [];
            continue;
        end

        force_keep = (cell_status(cid) == +1);

        if ~force_keep && ~ismember(cid, selected_cells_from_cutoff)
            Acttmp2{cid} = [];
            thresholds(cid) = NaN;
            Raster(cid,:) = false;
            StartEnd{cid} = [];
            continue;
        end

        x = DF_sg(cid,:).';

        if isempty(x) || all(~isfinite(x))
            Acttmp2{cid} = [];
            thresholds(cid) = NaN;
            StartEnd{cid} = [];
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

        Acttmp2{cid}    = out.locs_merged;
        thresholds(cid) = out.threshold;
        StartEnd{cid}   = out.intervals_merged;

        if ~isempty(out.locs_merged)
            Raster(cid, out.locs_merged) = true;
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

    DF_sg      = DF_sg(valid_cells, :);
    F0         = F0(valid_cells, :);
    thresholds = thresholds(valid_cells, :);
    Acttmp2    = Acttmp2(valid_cells);
    StartEnd   = StartEnd(valid_cells);
    Raster     = Raster(valid_cells, :);
end

%% ===================== NAVIGATION / CUTOFF =====================

function update_quality_threshold(fig, idx_slider)

    viewer_mode = isappdata(fig,'viewer_mode') && getappdata(fig,'viewer_mode');

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

    sldr = findobj(fig,'Tag','sldr_quality_thr');
    if ~isempty(sldr) && isgraphics(sldr)
        set(sldr,'Min',1,'Max',numel(order_cells),'Value',idx);
        step = 1/max(1,numel(order_cells)-1);
        set(sldr,'SliderStep',[step min(1,10*step)]);
    end

    lbl = findobj(fig,'Tag','lbl_quality_thr');
    if ~isempty(lbl)
        lbl.String = sprintf('Navigation cellule (%d / %d)', idx, numel(order_cells));
    end

    setappdata(fig,'auto_intervals', []);
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
    update_quality_threshold(fig, idx);
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
    update_quality_threshold(fig, idx);
end

function goto_navigation_index(fig, hEdit)

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
    update_quality_threshold(fig, idx);
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

    good_by_peaks = n_peaks_all >= opts.min_n_peaks_cutoff;

    if ~isempty(mask_sizes) && numel(mask_sizes) == numel(n_peaks_all)
        good_by_mask = mask_sizes >= opts.min_mask_pixels;
    else
        good_by_mask = true(size(n_peaks_all));
    end

    selected_cells_from_cutoff = find(good_by_peaks & good_by_mask);

    setappdata(fig,'selected_cells_from_cutoff', selected_cells_from_cutoff);
    setappdata(fig,'cutoff_validated', true);
    setappdata(fig,'cutoff_locked', true);

    fprintf('Cutoff auto : >= %d pics ET masque >= %d pixels.\n', ...
        opts.min_n_peaks_cutoff, opts.min_mask_pixels);
end

function validate_selection_filter(fig)

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
    min_mask_pixels = opts.min_mask_pixels;

    mask_sizes = [];
    if isappdata(fig,'mask_sizes')
        mask_sizes = getappdata(fig,'mask_sizes');
    end

    good_by_peaks = n_peaks_all >= min_n_peaks;

    if ~isempty(mask_sizes) && numel(mask_sizes) == numel(n_peaks_all)
        good_by_mask = mask_sizes >= min_mask_pixels;
    else
        good_by_mask = true(size(n_peaks_all));
    end

    auto_keep   = find(good_by_peaks & good_by_mask);
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

    setappdata(fig,'current_rank', 1);
    setappdata(fig,'nav_rank', 1);
    setappdata(fig,'cell_id', order_cells(1));

    sldr = findobj(fig,'Tag','sldr_quality_thr');
    if ~isempty(sldr) && isgraphics(sldr)
        n = numel(order_cells);
        set(sldr,'Min',1,'Max',max(1,n),'Value',1);
        step = 1/max(1,n-1);
        set(sldr,'SliderStep',[step min(1,10*step)]);
    end

    lbl = findobj(fig,'Tag','lbl_quality_thr');
    if ~isempty(lbl)
        lbl.String = sprintf('Navigation cellule (%d / %d)', 1, numel(order_cells));
    end

    setappdata(fig,'auto_intervals', []);
    setappdata(fig,'auto_peaks', []);
    if isappdata(fig,'seuil_detection_last')
        rmappdata(fig,'seuil_detection_last');
    end

    update_quality_threshold(fig, 1);

    fprintf('Validation appliquée : %d cellules affichées (manual keep + >= %d pics + masque >= %d px).\n', ...
        numel(order_cells), min_n_peaks, min_mask_pixels);
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

        sldr = findobj(fig,'Tag','sldr_quality_thr');
        if ~isempty(sldr) && isgraphics(sldr)
            set(sldr,'Min',1,'Max',1,'Value',1,'SliderStep',[1 1]);
        end

        hEdit = findobj(fig,'Tag','edit_nav_rank');
        if ~isempty(hEdit) && isgraphics(hEdit(1))
            set(hEdit(1),'String','1');
        end

        lbl = findobj(fig,'Tag','lbl_quality_thr');
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

    sldr = findobj(fig,'Tag','sldr_quality_thr');
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

    lbl = findobj(fig,'Tag','lbl_quality_thr');
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

    if ~viewer_mode && isappdata(fig,'order_cells_all') && isappdata(fig,'order_cells')
        order_cells_all = getappdata(fig,'order_cells_all');
        order_cells     = getappdata(fig,'order_cells');
    
        if numel(order_cells) == numel(order_cells_all)
            validate_selection_filter(fig);
        end
    end

    [invalid_cells, valid_cells, DF_sg, F0, Raster, Acttmp2, StartEnd, MAct, thresholds, opts, summary] = ...
        save_peak_matrix(fig, synchronous_frames);

    % Aperçu aléatoire de 10 traces sauvegardées avec pics
    try
        if isappdata(fig,'gcamp_output_folder')
            outdir_preview = getappdata(fig,'gcamp_output_folder');
        else
            outdir_preview = '';
        end
    
        create_random_peak_preview(valid_cells, DF_sg, Acttmp2, thresholds, outdir_preview);
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
    if iscell(StartEnd) && size(StartEnd,2) > 1
        StartEnd = reshape(StartEnd, [], 1);
    end

    setappdata(fig,'last_save_outputs', struct( ...
        'invalid_cells', invalid_cells, ...
        'valid_cells', valid_cells, ...
        'orig2new', orig2new, ...
        'DF_sg', DF_sg, ...
        'F0', F0, ...
        'Raster', Raster, ...
        'Acttmp2', {Acttmp2}, ...
        'StartEnd', {StartEnd}, ...
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
    DF_sg   = getappdata(fig,'DF_sg');
    F0      = getappdata(fig,'F0');
    cell_id = getappdata(fig,'cell_id');
    
    ax = getappdata(fig,'ax1');
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

    x = DF_sg(cell_id,:);
    x = x(:).';
    T = numel(x);
    t = 1:T;

    xlim(ax,[1 max(1,T)]);
    plot(ax,t,x,'k-');
    hold(ax,'on');

    % ---- Trace F0 ----
    if ~isempty(F0) && cell_id >= 1 && cell_id <= size(F0,1)
        f0 = F0(cell_id,:);
        f0 = f0(:).';
    
        xlim(axF0,[1 max(1,T)]);
        plot(axF0, t, f0, 'b-');
        hold(axF0,'on');
    
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
    ylabel(ax,'\DeltaF/F (SavGol)');

    % ---- Pics / intervalles auto ----
    if isappdata(fig,'auto_peaks') && isappdata(fig,'auto_intervals')
        auto_peaks = getappdata(fig,'auto_peaks');
        %intervals  = getappdata(fig,'auto_intervals');

        auto_peaks = auto_peaks(auto_peaks>=1 & auto_peaks<=T);
        % intervals  = intervals(all(intervals>0,2) & all(intervals<=T,2), :);
        % 
        % if ~isempty(intervals)
        %     for i = 1:size(intervals,1)
        %         a = intervals(i,1);
        %         b = intervals(i,2);
        % 
        %         plot(ax, a, x(a), 'g^', ...
        %             'MarkerFaceColor',[0.2 0.8 0.2], ...
        %             'MarkerEdgeColor',[0 0.6 0], ...
        %             'MarkerSize',6, 'LineWidth',1);
        % 
        %         plot(ax, b, x(b), 'rv', ...
        %             'MarkerFaceColor',[1 0.5 0.5], ...
        %             'MarkerEdgeColor','r', ...
        %             'MarkerSize',6, 'LineWidth',1);
        % 
        %         plot(ax, [a b], [x(a) x(b)], '-', ...
        %             'Color',[1 0.6 0.6 0.35], 'LineWidth',0.8);
        %     end
        % end

        if ~isempty(auto_peaks)
            plot(ax, auto_peaks, x(auto_peaks), 'r*', ...
                'MarkerSize',8, 'LineWidth',1.2);
        end
    end

    % ---- Seuil ----
    if isappdata(fig,'seuil_detection_last')
        seuil_detection = getappdata(fig,'seuil_detection_last');
        if isfinite(seuil_detection)
            plot(ax,[1 max(1,T)],[seuil_detection seuil_detection],':', ...
                'Color',[.7 .1 .1],'LineWidth',1);
        end
    end

    % ---- Labels GOOD/BAD (désactivés en viewer_mode) ----
    viewer_mode = isappdata(fig,'viewer_mode') && getappdata(fig,'viewer_mode');

    % ---- Label électroporée si cellule courante dans blue_indices ----
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

                % priorité au manuel
                if st(cell_id) == -1
                    if ~isempty(n_peaks_all) && cell_id <= numel(n_peaks_all) && n_peaks_all(cell_id) == 0
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
                                    cond_mask = mask_sizes(cell_id) >= opts.min_mask_pixels;
                                end
                            end
                        
                            if cond_peaks && cond_mask
                                label_txt   = sprintf('GOOD (peaks+mask)');
                                label_color = [0.1 0.6 0.1];
                            else
                                label_txt   = sprintf('BAD (peaks/mask)');
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
    % Pixel size depuis meta_tbl
    % ----------------------------
    pixel_size_um = NaN;
    if isappdata(fig,'meta_tbl')
        meta_tbl = getappdata(fig,'meta_tbl');
        try
            if istable(meta_tbl) && any(strcmp(meta_tbl.Properties.VariableNames,'PixelSize'))
                px = meta_tbl.PixelSize;

                if isnumeric(px)
                    pixel_size_um = double(px(1));
                elseif iscell(px) && ~isempty(px)
                    pixel_size_um = str2double(string(px{1}));
                elseif isstring(px) || ischar(px)
                    pixel_size_um = str2double(string(px(1)));
                end
            end
        catch
            pixel_size_um = NaN;
        end
    end

    % ----------------------------
    % Récupération masque (stack N x H x W)
    % ----------------------------
    mask = [];
    if isappdata(fig,'masks')
        masks = getappdata(fig,'masks');

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
    title(ax, sprintf('Cellule %d', cid));

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
    intFields = {'savgol_win','min_width_fr','refrac_fr'};
    if ismember(field,intFields)
        val = round(max(minv, min(maxv, val)));
        fmt = '%s = %d';
    else
        val = max(minv, min(maxv, val));
        fmt = '%s = %.2f';
    end

    uicontrol('Parent',parent,'Style','text','String',sprintf(fmt,label,val), ...
        'Units','normalized','Position',[pos(1) pos(2)+0.05 pos(3) 0.04], ...
        'Tag',['lbl_' field],'HorizontalAlignment','left','FontWeight','normal');

    uicontrol('Parent',parent,'Style','slider','Min',minv,'Max',maxv,'Value',val, ...
        'Units','normalized','Position',pos, ...
        'Callback',@(src,~) update_param(fig,field,get(src,'Value')));
end

function update_param(fig, field, value)
    opts = getappdata(fig,'opts');
    intFields = {'savgol_win','min_width_fr','refrac_fr','window_size'};

    if ismember(field,intFields)
        if strcmp(field,'savgol_win')
            value = round(value);
            if value < 3, value = 3; end
            if mod(value,2)==0, value = value+1; end
        else
            value = round(max(1, value));
        end
    else
        value = max(0, value);
    end

    opts.(field) = value;
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

    % Recalcul si window_size ou SavGol changent
    if ismember(field, {'window_size','savgol_win'})
        F_raw = getappdata(fig,'F_raw');
        fs    = getappdata(fig,'fs');

        bad_frames = [];
        if isappdata(fig,'bad_frames')
            bad_frames = getappdata(fig,'bad_frames');
        end

        [Fdetrend, F0] = F_processing(F_raw, bad_frames, fs, opts.window_size);
        DF_sg = DF_processing(Fdetrend, opts);
        noise_est = estimate_noise(Fdetrend);

        setappdata(fig,'F0', F0);
        setappdata(fig,'DF_sg', DF_sg);
        setappdata(fig,'noise_est', noise_est);

        [~, SNR, ~, cells_sorted_by_quality, ~, ~, ~] = ...
            compute_snr_quality(DF_sg, noise_est, opts, bad_frames);

        setappdata(fig,'SNR', SNR);
        setappdata(fig,'cells_sorted_by_quality', cells_sorted_by_quality);
    end

    setappdata(fig,'auto_intervals', []);
    setappdata(fig,'auto_peaks', []);
    if isappdata(fig,'seuil_detection_last')
        rmappdata(fig,'seuil_detection_last');
    end

    recompute_n_peaks_all(fig);
    apply_auto_cutoff(fig);
    refresh_selection_order(fig);
    auto_detect_and_add(fig);
end

%% ===================== UTILITIES =====================

function segs = badframes_to_segments(bad_frames, T)
    if isempty(bad_frames) || T<=0
        segs = zeros(0,2);
        return;
    end

    if islogical(bad_frames)
        bf = bad_frames(:).';
        if numel(bf) ~= T
            bf = bf(1:min(end,T));
            if numel(bf) < T, bf(end+1:T) = false; end
        end
        idx = find(bf);
    else
        idx = bad_frames(:).';
        idx = idx(isfinite(idx));
        idx = unique(round(idx));
        idx = idx(idx>=1 & idx<=T);
    end

    if isempty(idx)
        segs = zeros(0,2);
        return;
    end

    d = diff(idx);
    cuts = [1 find(d>1)+1 numel(idx)+1];

    segs = zeros(numel(cuts)-1,2);
    for k = 1:numel(cuts)-1
        a = idx(cuts(k));
        b = idx(cuts(k+1)-1);
        segs(k,:) = [a b];
    end
end

function [user_segs, user_frames] = enter_observed_deviations(tifPath, T)

    if nargin < 1
        error('Usage: [user_segs,user_frames] = enter_observed_deviations(tifPath,T)');
    end
    if nargin < 2, T = []; end

    if ~exist(tifPath,'file')
        error('TIFF introuvable : %s', tifPath);
    end

    fprintf('\n=== OUVRIR MANUELLEMENT DANS FIJI ===\n');
    fprintf('Fichier TIFF :\n%s\n\n', tifPath);
    fprintf('Ouvre ce fichier dans Fiji, observe les déviations,\n');
    fprintf('puis reviens ici pour entrer les frames correspondantes.\n\n');

    fprintf('Entrée attendue (FRAMES uniquement) :\n');
    fprintf('  ex: 120:140\n');
    fprintf('      [120:140 300:320]\n');
    fprintf('[] si aucune déviation.\n\n');

    x = input('Frames observées = ');

    if isempty(x)
        fprintf('Aucune déviation saisie.\n');
        user_segs = zeros(0,2);
        user_frames = [];
        return;
    end

    if ~isnumeric(x) || ~isvector(x)
        error('Entrée invalide: entrer UNIQUEMENT un vecteur de frames.');
    end

    fr = round(x(:).');
    fr = fr(isfinite(fr));

    if ~isempty(T)
        fr = fr(fr>=1 & fr<=T);
    else
        fr = fr(fr>=1);
    end

    fr = unique(fr);

    user_segs = frames_to_segments(fr);
    user_frames = fr;

    fprintf('\n=== Enregistré ===\n');
    fprintf('Segments détectés: %d\n', size(user_segs,1));
    if ~isempty(user_segs)
        disp(user_segs);
    end
end

function segs = frames_to_segments(fr)
    if isempty(fr)
        segs = zeros(0,2);
        return;
    end
    d = diff(fr);
    cuts = [1 find(d>1)+1 numel(fr)+1];
    segs = zeros(numel(cuts)-1,2);
    for k = 1:numel(cuts)-1
        segs(k,:) = [fr(cuts(k)) fr(cuts(k+1)-1)];
    end
end

function segTable = sort_segments_by_deviation(bad_segs, deviation)

    if nargin < 2
        error('Usage: segTable = sort_segments_by_deviation(bad_segs, deviation)');
    end

    deviation = deviation(:).';
    T = numel(deviation);

    if isempty(bad_segs)
        segTable = table([], [], [], [], ...
            'VariableNames', {'StartFrame','EndFrame','FrameExtent','ValMaxDeviation'});
        disp(segTable);
        return;
    end

    if size(bad_segs,2) ~= 2
        error('bad_segs doit être une matrice Nx2 [start end].');
    end

    N = size(bad_segs,1);

    startF = nan(N,1);
    endF   = nan(N,1);
    extent = nan(N,1);
    valMax = nan(N,1);

    for k = 1:N
        a = round(bad_segs(k,1));
        b = round(bad_segs(k,2));

        if a > b
            tmp = a; a = b; b = tmp;
        end

        a = max(1, min(T, a));
        b = max(1, min(T, b));

        startF(k) = a;
        endF(k)   = b;
        extent(k) = b - a + 1;

        segVals = deviation(a:b);
        segVals = segVals(isfinite(segVals));

        if isempty(segVals)
            valMax(k) = NaN;
        else
            valMax(k) = min(segVals);
        end
    end

    segTable = table(startF, endF, extent, valMax, ...
        'VariableNames', {'StartFrame','EndFrame','FrameExtent','ValMaxDeviation'});

    segTable = sortrows(segTable, 'ValMaxDeviation', 'ascend');
end

function create_random_peak_preview(valid_cells, DF_sg, Acttmp2, thresholds, outdir_preview)
% Crée une figure avec jusqu'à 10 cellules tirées au hasard parmi
% les cellules gardées, affiche leurs traces + pics détectés,
% et sauvegarde automatiquement un PNG si absent.

    if nargin < 4
        thresholds = [];
    end
    if nargin < 5
        outdir_preview = '';
    end

    if isempty(valid_cells) || isempty(DF_sg)
        warning('Aucune cellule valide à afficher dans la preview.');
        return;
    end

    nCellsFinal = size(DF_sg, 1);
    if nCellsFinal == 0
        warning('DF_sg final vide, preview non générée.');
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
        x = DF_sg(ii, :);
        t = 1:numel(x);

        nexttile;
        hold on;
        box on;

        plot(t, x, 'k-', 'LineWidth', 1);

        pk = [];
        if iscell(Acttmp2) && numel(Acttmp2) >= ii && ~isempty(Acttmp2{ii})
            pk = Acttmp2{ii};
            pk = pk(:)';
            pk = pk(isfinite(pk) & pk >= 1 & pk <= numel(x));
        end

        if ~isempty(pk)
            plot(pk, x(pk), 'r*', 'MarkerSize', 6, 'LineWidth', 1);
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
    %if ~isempty(png_path)
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
    %end
end