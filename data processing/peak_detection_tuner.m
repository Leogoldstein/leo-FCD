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
        'window_size', 600, ...
        'savgol_win', 9, ...
        'savgol_poly', 3, ...
        'min_width_fr', 6, ...
        'prominence_factor', 0.8, ...
        'refrac_fr', 3 ...
    );

    % ---- Inputs optionnels ----
    iscell_in = [];
    stat_in   = [];
    speed     = [];
    deviation = [];
    bad_frames = [];
    focus_segs = [];
    gcamp_TSeries_path = '';
    meanImg = [];
    ops = [];
    meta_tbl = [];
    viewer_mode = false;

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

                case 'meanImg'
                    meanImg = val;

                case 'gcamp_TSeries_path'
                    gcamp_TSeries_path = val;

                case 'speed'
                    speed = val;

                case 'meta_tbl'
                    meta_tbl = val;
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
    [F0, Fdetrend] = F_processing(F, bad_frames, window_size);
    noise_est = estimate_noise(Fdetrend);
    DF_sg = DF_processing(Fdetrend, opts, window_size);

    % ---- Qualité / SNR ----
    [~, SNR, ~, cells_sorted_by_quality, ~, ~, ~] = compute_snr_quality(DF_sg, noise_est);

    % ---- Titre fenêtre ----
    winTitle = '';
    if viewer_mode
        winTitle = [winTitle '  [VIEWER MODE]'];
    elseif ~isempty(gcamp_TSeries_path)
        planePath = fileparts(gcamp_TSeries_path);
        nCells = size(F,1);
        winTitle = sprintf('%s | nCells=%d', planePath, nCells);
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
        cutoff_cb   = @(~,~) [];
        validate_cb = @(~,~) [];
        keep_cb     = @(~,~) [];
        exclude_cb  = @(~,~) [];
    else
        cutoff_cb   = @(~,~) define_cutoff(fig);
        validate_cb = @(~,~) validate_selection_filter(fig);
        keep_cb     = @(~,~) keep_cell(fig);
        exclude_cb  = @(~,~) exclude_cell(fig);
    end
    
    finalize_cb = @(~,~) finalize_and_close(fig, synchronous_frames);

    uicontrol('Parent',ctrl_panel,'Style','text', ...
        'String', sprintf('Navigation cellule (1 / %d)', size(F,1)), ...
        'Units','normalized','Position',[0.05 0.93 0.90 0.035], ...
        'Tag','lbl_quality_thr', ...
        'HorizontalAlignment','left', ...
        'BackgroundColor',[.97 .97 .98]);

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
        'Position',[0.05 0.84 0.90 0.06], ...
        'Tag','sldr_quality_thr', ...
        'Callback', @(src,~) update_quality_threshold(fig, round(get(src,'Value'))));
        
    uicontrol('Parent',ctrl_panel,'Style','pushbutton', ...
        'String','Définir cutoff', ...
        'Units','normalized','Position',[0.05 0.24 0.90 0.06], ...
        'BackgroundColor',[0.75 0.75 0.85], ...
        'ForegroundColor','k', ...
        'FontWeight','bold', ...
        'FontSize',11, ...
        'Callback', cutoff_cb);
    
    uicontrol('Parent',ctrl_panel,'Style','pushbutton', ...
        'String','Valider sélection', ...
        'Units','normalized','Position',[0.05 0.17 0.90 0.06], ...
        'BackgroundColor',[0.20 0.45 0.90], ...
        'ForegroundColor','w', ...
        'FontWeight','bold', ...
        'FontSize',12, ...
        'Callback', validate_cb);
    
    uicontrol('Parent',ctrl_panel,'Style','pushbutton', ...
        'String','Garder cellule', ...
        'Units','normalized','Position',[0.05 0.11 0.42 0.07], ...
        'BackgroundColor',[0.10 0.60 0.10], ...
        'ForegroundColor','w', ...
        'FontWeight','bold', ...
        'FontSize',11, ...
        'Callback', keep_cb);
    
    uicontrol('Parent',ctrl_panel,'Style','pushbutton', ...
        'String','Exclure cellule', ...
        'Units','normalized','Position',[0.53 0.11 0.42 0.07], ...
        'BackgroundColor',[0.80 0.15 0.15], ...
        'ForegroundColor','w', ...
        'FontWeight','bold', ...
        'FontSize',11, ...
        'Callback', exclude_cb);
    
    uicontrol('Parent',ctrl_panel,'Style','pushbutton', ...
        'String','Confirmer sélection', ...
        'Units','normalized','Position',[0.05 0.02 0.90 0.08], ...
        'BackgroundColor',[0.1 0.6 0.35], ...
        'ForegroundColor','w', ...
        'FontWeight','bold', ...
        'FontSize',12, ...
        'Callback', finalize_cb);

    if viewer_mode
        set(findobj(ctrl_panel,'String','Définir cutoff'),'Enable','off');
        set(findobj(ctrl_panel,'String','Valider sélection'),'Enable','off');
        set(findobj(ctrl_panel,'String','Garder cellule'),'Enable','off');
        set(findobj(ctrl_panel,'String','Exclure cellule'),'Enable','off');
    end

    % ---- Contrôles détection ----
    make_slider(ctrl_panel,fig,'Largeur min (fr)','min_width_fr',0,50,opts.min_width_fr,[0.05 0.70 0.90 0.06]);
    make_slider(ctrl_panel,fig,'Prominence','prominence_factor',0,3,opts.prominence_factor,[0.05 0.64 0.90 0.06]);
    make_slider(ctrl_panel,fig,'Réfractaire (fr)','refrac_fr',0,10,opts.refrac_fr,[0.05 0.58 0.90 0.06]);
    make_slider(ctrl_panel,fig,'SavGol window','savgol_win',3,51,opts.savgol_win,[0.05 0.52 0.90 0.06]);

    % ---- Axe principal ----
    ax1 = axes('Parent',fig,'Position',[0.28 0.60 0.70 0.33]);
    box(ax1,'on');
    xlabel(ax1,'Frames');
    ylabel(ax1,'\DeltaF/F (SavGol)');
    plot(ax1,NaN,NaN,'k-');
    hold(ax1,'on');

    % ---- Axe déviation ----
    axDev = axes('Parent',fig,'Position',[0.28 0.52 0.70 0.07]);
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
    
    % cell_status: 0 undecided, +1 keep, -1 exclude
    setappdata(fig,'cell_status', zeros(size(F,1),1));
    
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

        hBadDev = create_badframe_patch(axDev, focus_segs);
        setappdata(fig,'hBadPatch_axDev', hBadDev);
    end

    linkaxes([ax1 axDev],'x');

    % ---- Recompute pics ----
    recompute_n_peaks_all(fig);

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
            fprintf('Total cellules                  : %d\n', s.n_total);
            fprintf('Cellules sans pics (auto exclues): %d\n', s.n_zero_peaks);
            fprintf('Manuelles KEEP                  : %d\n', s.n_manual_keep);
            fprintf('Manuelles EXCLUES               : %d\n', s.n_manual_excl);
            fprintf('Validées par cutoff             : %d\n', s.n_kept_by_cutoff);
            fprintf('---------------------------------------------\n');
            fprintf('Cellules finales gardées        : %d\n', s.n_kept_final);
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

function DF_sg = DF_processing(Fdetrend, opts, window_size)

    sg_win  = opts.savgol_win;
    sg_poly = opts.savgol_poly;

    [NCell, Nz] = size(Fdetrend);

    DF_sg          = nan(NCell, Nz);
    DF_plate       = nan(NCell, Nz); %#ok<NASGU>
    baseline_local = nan(NCell, Nz);

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
        baseline_local(n,:) = movmedian(Fdetrend(n,:), window_size, 'omitnan');
        sig = Fdetrend(n,:) - baseline_local(n,:);
        DF_plate(n,:) = sig;

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
    compute_snr_quality(DF_sg, noise_est)

    if nargin < 2
        error('compute_snr_quality requires DF_sg and noise_est.');
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

    p995 = prctile(DF_sg, 99.5, 2);
    p50  = prctile(DF_sg, 50, 2);

    A = p995 - p50;
    A(~isfinite(A) | A < 0) = 0;

    SNR = A ./ noise_est;
    SNR(~isfinite(SNR)) = 0;

    score = SNR(:);

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

    if isappdata(fig,'order_cells_all')
        order_cells_all = getappdata(fig,'order_cells_all');
    else
        order_cells_all = [];
    end
    
    if cutoff_validated && isappdata(fig,'cutoff_rank') && ~isempty(order_cells_all)
        nav_cutoff = round(getappdata(fig,'cutoff_rank'));
        nav_cutoff = max(1, min(numel(order_cells_all), nav_cutoff));
        selected_cells_from_cutoff = order_cells_all(nav_cutoff:end);
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

        out = detect_peaks_cell_core(x, noise_est(cid), opts, bad_frames);

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

    if ~viewer_mode
        if isappdata(fig,'cutoff_locked') && ~getappdata(fig,'cutoff_locked')
            setappdata(fig,'cutoff_rank', idx);
        end
    end

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

function define_cutoff(fig)

    if ~ishghandle(fig)
        return;
    end

    if isappdata(fig,'viewer_mode') && getappdata(fig,'viewer_mode')
        return;
    end

    if ~isappdata(fig,'order_cells_all')
        return;
    end

    order_cells_all = getappdata(fig,'order_cells_all');
    if isempty(order_cells_all)
        return;
    end

    hEdit = findobj(fig,'Tag','edit_nav_rank');
    if isempty(hEdit) || ~isgraphics(hEdit(1))
        return;
    end
    hEdit = hEdit(1);

    txt = get(hEdit, 'String');
    idx = str2double(txt);

    if ~isfinite(idx)
        idx = 1;
    end

    idx = round(idx);
    idx = max(1, min(numel(order_cells_all), idx));

    setappdata(fig,'cutoff_rank', idx);
    setappdata(fig,'cutoff_locked', true);

    % IMPORTANT:
    % cutoff défini pour affichage GOOD/BAD, mais pas encore filtré
    setappdata(fig,'cutoff_validated', true);

    set(hEdit, 'String', num2str(idx));

    refresh_data(fig);
    update_peak_histogram(fig);

    fprintf('Cutoff défini à %d. Labels GOOD/BAD (cutoff) affichés. Filtrage non encore appliqué.\n', idx);
end

function validate_selection_filter(fig)

    if ~isappdata(fig,'order_cells_all')
        return;
    end

    order_cells_all = getappdata(fig,'order_cells_all');
    if isempty(order_cells_all)
        return;
    end

    if ~isappdata(fig,'cutoff_rank')
        return;
    end

    if isappdata(fig,'viewer_mode') && getappdata(fig,'viewer_mode')
        return;
    end

    cutoff_rank = round(getappdata(fig,'cutoff_rank'));
    cutoff_rank = max(1, min(numel(order_cells_all), cutoff_rank));

    if isappdata(fig,'cell_status')
        st = getappdata(fig,'cell_status');
    else
        st = zeros(max(order_cells_all),1);
    end

    % cellules gardées par cutoff
    cutoff_cells = order_cells_all(cutoff_rank:end);

    % cellules gardées manuellement
    manual_keep = find(st == +1);

    % exclusions manuelles
    manual_excl = find(st == -1);

    kept_cells = unique([manual_keep(:); cutoff_cells(:)], 'stable');
    kept_cells = setdiff(kept_cells, manual_excl, 'stable');

    if isempty(kept_cells)
        warning('Aucune cellule retenue après validation.');
        return;
    end

    keep_mask = ismember(order_cells_all, kept_cells);
    order_cells = order_cells_all(keep_mask);

    setappdata(fig,'order_cells', order_cells);

    % cutoff toujours actif
    setappdata(fig,'cutoff_locked', true);
    setappdata(fig,'cutoff_validated', true);

    % repositionnement sur la première cellule visible
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

    refresh_data(fig);
    update_peak_histogram(fig);

    fprintf('Validation appliquée : %d cellules affichées (manual keep + cutoff).\n', numel(order_cells));
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

    % avant validation visuelle finale, on affiche tout l’ordre complet
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

    % si le cutoff n’est pas verrouillé, il suit la navigation
    locked = isappdata(fig,'cutoff_locked') && getappdata(fig,'cutoff_locked');
    if ~locked
        setappdata(fig,'cutoff_rank', idx);
    end

    sldr = findobj(fig,'Tag','sldr_quality_thr');
    if ~isempty(sldr) && isgraphics(sldr)
        n = numel(order_cells);
        set(sldr,'Min',1,'Max',n,'Value',idx);
        step = 1/max(1,n-1);
        set(sldr,'SliderStep',[step min(1,10*step)]);
    end

    lbl = findobj(fig,'Tag','lbl_quality_thr');
    if ~isempty(lbl)
        lbl.String = sprintf('Navigation cellule (%d / %d)', idx, numel(order_cells));
    end

    auto_detect_and_add(fig);
end

function set_cutoff_from_edit(fig)

    if ~ishghandle(fig)
        return;
    end

    if ~isappdata(fig,'order_cells')
        return;
    end

    order_cells = getappdata(fig,'order_cells');
    if isempty(order_cells)
        return;
    end

    hEdit = findobj(fig,'Tag','edit_nav_rank');
    if isempty(hEdit) || ~isgraphics(hEdit(1))
        return;
    end
    hEdit = hEdit(1);

    txt = get(hEdit, 'String');
    idx = str2double(txt);

    if ~isfinite(idx)
        idx = 1;
    end

    idx = round(idx);
    idx = max(1, min(numel(order_cells), idx));

    setappdata(fig,'cutoff_rank', idx);
    setappdata(fig,'nav_rank', idx);

    % Le cutoff est défini mais pas encore validé
    setappdata(fig,'cutoff_validated', false);
    setappdata(fig,'cutoff_locked', false);

    set(hEdit, 'String', num2str(idx));

    fprintf('Cutoff défini à %d (non validé).\n', idx);
end

function validate_cutoff_and_filter(fig)

    if ~isappdata(fig,'order_cells_all')
        return;
    end

    order_cells_all = getappdata(fig,'order_cells_all');
    if isempty(order_cells_all)
        return;
    end

    % récup cutoff depuis l'edit
    set_cutoff_from_edit(fig);

    cutoff_rank = getappdata(fig,'cutoff_rank');
    cutoff_rank = max(1, min(numel(order_cells_all), cutoff_rank));

    if isappdata(fig,'cell_status')
        st = getappdata(fig,'cell_status');
    else
        st = zeros(max(order_cells_all),1);
    end

    % cellules retenues par cutoff parmi l'ordre global visible initial
    cutoff_cells = order_cells_all(cutoff_rank:end);

    % manual keep toujours gardées
    manual_keep = find(st == +1);

    % union manual + cutoff
    kept_cells = unique([manual_keep(:); cutoff_cells(:)], 'stable');

    % retirer exclusions manuelles
    manual_excl = find(st == -1);
    kept_cells = setdiff(kept_cells, manual_excl, 'stable');

    if isempty(kept_cells)
        warning('Aucune cellule retenue après validation du cutoff.');
        return;
    end

    % garder l'ordre qualité initial
    kept_mask = ismember(order_cells_all, kept_cells);
    order_cells_filtered = order_cells_all(kept_mask);

    setappdata(fig,'order_cells', order_cells_filtered);
    setappdata(fig,'cutoff_validated', true);
    setappdata(fig,'cutoff_locked', true);

    % se replacer sur la première cellule retenue
    setappdata(fig,'current_rank', 1);
    setappdata(fig,'nav_rank', 1);
    setappdata(fig,'cell_id', order_cells_filtered(1));

    % sync UI
    sldr = findobj(fig,'Tag','sldr_quality_thr');
    if ~isempty(sldr) && isgraphics(sldr)
        n = numel(order_cells_filtered);
        set(sldr,'Min',1,'Max',max(1,n),'Value',1);
        step = 1/max(1,n-1);
        set(sldr,'SliderStep',[step min(1,10*step)]);
    end

    lbl = findobj(fig,'Tag','lbl_quality_thr');
    if ~isempty(lbl)
        lbl.String = sprintf('Navigation cellule (%d / %d)', 1, numel(order_cells_filtered));
    end

    hEdit = findobj(fig,'Tag','edit_nav_rank');
    if ~isempty(hEdit) && isgraphics(hEdit(1))
        set(hEdit(1), 'String', num2str(cutoff_rank));
    end

    setappdata(fig,'auto_intervals', []);
    if isappdata(fig,'seuil_detection_last')
        rmappdata(fig,'seuil_detection_last');
    end

    auto_detect_and_add(fig);

    fprintf('Cutoff validé à %d. %d cellules affichées (manual keep + cutoff).\n', ...
        cutoff_rank, numel(order_cells_filtered));
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

    if isappdata(fig,'order_cells_all') && isappdata(fig,'order_cells')
        order_cells_all = getappdata(fig,'order_cells_all');
        order_cells     = getappdata(fig,'order_cells');

        % si on n'a pas encore filtré, on filtre maintenant
        if numel(order_cells) == numel(order_cells_all)
            validate_selection_filter(fig);
        end
    end

    [invalid_cells, valid_cells, DF_sg, F0, Raster, Acttmp2, StartEnd, MAct, thresholds, opts, summary] = ...
        save_peak_matrix(fig, synchronous_frames);

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
    cell_id = getappdata(fig,'cell_id');

    ax = getappdata(fig,'ax1');

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

    x = DF_sg(cell_id,:);
    x = x(:).';
    T = numel(x);
    t = 1:T;

    xlim(ax,[1 max(1,T)]);
    plot(ax,t,x,'k-');
    hold(ax,'on');

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
        intervals  = getappdata(fig,'auto_intervals');

        auto_peaks = auto_peaks(auto_peaks>=1 & auto_peaks<=T);
        intervals  = intervals(all(intervals>0,2) & all(intervals<=T,2), :);

        if ~isempty(intervals)
            for i = 1:size(intervals,1)
                a = intervals(i,1);
                b = intervals(i,2);

                plot(ax, a, x(a), 'g^', ...
                    'MarkerFaceColor',[0.2 0.8 0.2], ...
                    'MarkerEdgeColor',[0 0.6 0], ...
                    'MarkerSize',6, 'LineWidth',1);

                plot(ax, b, x(b), 'rv', ...
                    'MarkerFaceColor',[1 0.5 0.5], ...
                    'MarkerEdgeColor','r', ...
                    'MarkerSize',6, 'LineWidth',1);

                plot(ax, [a b], [x(a) x(b)], '-', ...
                    'Color',[1 0.6 0.6 0.35], 'LineWidth',0.8);
            end
        end

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
                    if cutoff_validated && isappdata(fig,'cutoff_rank') && isappdata(fig,'order_cells_all')
                        cutoff_rank = round(getappdata(fig,'cutoff_rank'));
                        order_cells_all = getappdata(fig,'order_cells_all');

                        if ~isempty(order_cells_all)
                            cutoff_rank = max(1, min(numel(order_cells_all), cutoff_rank));
                            selected_cells_from_cutoff = order_cells_all(cutoff_rank:end);

                            if ismember(cell_id, selected_cells_from_cutoff)
                                label_txt   = 'GOOD (cutoff)';
                                label_color = [0.1 0.6 0.1];
                            else
                                label_txt   = 'BAD (cutoff)';
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

    if ~isappdata(fig,'axROI'), return; end
    ax = getappdata(fig,'axROI');
    if isempty(ax) || ~ishghandle(ax), return; end

    meanImg = [];
    if isappdata(fig,'meanImg')
        meanImg = getappdata(fig,'meanImg');
    end
    if isempty(meanImg) || ~(isnumeric(meanImg) || islogical(meanImg))
        cla(ax);
        title(ax,'P(cellule)=NaN');
        text(ax,0.5,0.5,'meanImg non disponible/numérique', ...
            'Units','normalized','HorizontalAlignment','center');
        return;
    end
    meanImg = double(meanImg);

    if ~isappdata(fig,'cell_id')
        cla(ax);
        imagesc(ax, meanImg);
        colormap(ax,gray);
        axis(ax,'image');
        set(ax,'YDir','reverse');
        title(ax,'P(cellule)=NaN');
        return;
    end
    cid = round(getappdata(fig,'cell_id'));

    prob_cell = NaN;
    if isappdata(fig,'iscell')
        iscell_in = getappdata(fig,'iscell');
        try
            if isnumeric(iscell_in) || islogical(iscell_in)
                if size(iscell_in,1) >= cid && size(iscell_in,2) >= 2
                    prob_cell = double(iscell_in(cid,2));
                end
            elseif iscell(iscell_in)
                if size(iscell_in,1) >= cid && size(iscell_in,2) >= 2
                    prob_cell = double(iscell_in{cid,2});
                end
            end
        catch
            prob_cell = NaN;
        end
    end

    if isfinite(prob_cell)
        ttl = sprintf('Cellule %d — P(cellule)=%.3f', cid, prob_cell);
    else
        ttl = sprintf('Cellule %d — P(cellule)=NaN', cid);
    end

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

    if ~isappdata(fig,'stat')
        cla(ax);
        imagesc(ax, meanImg);
        colormap(ax,gray);
        axis(ax,'image');
        set(ax,'YDir','reverse');
        title(ax, ttl);
        add_scale_bar(ax, pixel_size_um);
        return;
    end
    stat_in = getappdata(fig,'stat');

    [xext, yext] = get_xext_yext(stat_in, cid, size(meanImg));

    cla(ax);
    hold(ax,'on');

    if isempty(xext) || isempty(yext) || numel(xext) < 3
        imagesc(ax, meanImg);
        colormap(ax,gray);
        axis(ax,'image');
        set(ax,'YDir','reverse');
        title(ax, ttl);
        add_scale_bar(ax, pixel_size_um);
        hold(ax,'off');
        return;
    end

    xext = xext(:);
    yext = yext(:);
    if xext(1) ~= xext(end) || yext(1) ~= yext(end)
        xext(end+1) = xext(1);
        yext(end+1) = yext(1);
    end

    pad = 12;

    xmin = floor(min(xext)) - pad;
    xmax = ceil(max(xext)) + pad;
    ymin = floor(min(yext)) - pad;
    ymax = ceil(max(yext)) + pad;

    [Himg,Wimg] = size(meanImg);
    xmin = max(1, xmin); xmax = min(Wimg, xmax);
    ymin = max(1, ymin); ymax = min(Himg, ymax);

    cropImg = meanImg(ymin:ymax, xmin:xmax);

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

    imagesc(ax, cropImg);
    colormap(ax, gray);
    axis(ax, 'image');
    set(ax,'YDir','reverse');
    clim(ax, [lo hi]);

    H = ymax - ymin + 1;
    W = xmax - xmin + 1;
    mask = false(H, W);

    xloc = round(xext - (xmin - 1));
    yloc = round(yext - (ymin - 1));

    valid = xloc>=1 & xloc<=W & yloc>=1 & yloc<=H;
    idx = sub2ind([H W], yloc(valid), xloc(valid));
    mask(idx) = true;

    mask = imclose(mask, strel('disk',1));
    mask = bwareaopen(mask, 10);

    B = bwboundaries(mask, 'noholes');

    if ~isempty(B)
        boundary = B{1};
        yb = boundary(:,1);
        xb = boundary(:,2);

        plot(ax, xb, yb, 'k-', 'LineWidth', 4);
        plot(ax, xb, yb, 'r-', 'LineWidth', 2.5);
    end

    add_scale_bar(ax, pixel_size_um);

    title(ax, ttl);
    hold(ax,'off');
end

function [x, y] = get_xext_yext(stat_in, cid, imgSize)

    x = [];
    y = [];

    if nargin < 3, imgSize = []; end
    if ~(isnumeric(cid)&&isscalar(cid)&&isfinite(cid)&&cid>=1), return; end
    cid = round(cid);

    s = [];
    if iscell(stat_in)
        if cid > numel(stat_in), return; end
        s = stat_in{cid};
    elseif isstruct(stat_in)
        if cid > numel(stat_in), return; end
        s = stat_in(cid);
    else
        return;
    end
    if ~isstruct(s), return; end

    if isfield(s,'xext') && isfield(s,'yext') && isnumeric(s.xext) && isnumeric(s.yext) ...
            && ~isempty(s.xext) && ~isempty(s.yext)
        x = double(s.xext(:)) + 1;
        y = double(s.yext(:)) + 1;
        return;
    end

    if ~(isfield(s,'xpix') && isfield(s,'ypix') && isnumeric(s.xpix) && isnumeric(s.ypix))
        return;
    end

    xp = double(s.xpix(:)) + 1;
    yp = double(s.ypix(:)) + 1;

    good = isfinite(xp) & isfinite(yp);
    xp = xp(good); yp = yp(good);
    if numel(xp) < 3, return; end

    if ~isempty(imgSize) && numel(imgSize)==2
        H = imgSize(1); W = imgSize(2);
        in = xp>=1 & xp<=W & yp>=1 & yp<=H;
        xp = xp(in); yp = yp(in);
        if numel(xp) < 3, return; end
    end

    pad = 2;
    xmin = floor(min(xp))-pad; xmax = ceil(max(xp))+pad;
    ymin = floor(min(yp))-pad; ymax = ceil(max(yp))+pad;

    if ~isempty(imgSize) && numel(imgSize)==2
        H = imgSize(1); W = imgSize(2);
        xmin = max(1,xmin); xmax = min(W,xmax);
        ymin = max(1,ymin); ymax = min(H,ymax);
    end

    w = xmax - xmin + 1;
    h = ymax - ymin + 1;
    if w<=2 || h<=2, return; end

    mask = false(h,w);
    xloc = round(xp - xmin + 1);
    yloc = round(yp - ymin + 1);

    ok = xloc>=1 & xloc<=w & yloc>=1 & yloc<=h;
    if nnz(ok) < 3, return; end
    mask(sub2ind([h w], yloc(ok), xloc(ok))) = true;

    mask = imclose(mask, strel('disk',1));
    mask = imfill(mask,'holes');

    B = bwboundaries(mask, 'noholes');
    if isempty(B), return; end

    [~, imax] = max(cellfun(@(b) size(b,1), B));
    b = B{imax};
    yb = b(:,1);
    xb = b(:,2);

    x = xb + (xmin - 1);
    y = yb + (ymin - 1);
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

function plot_raster_window(Raster, focus_segs)

    if nargin < 2
        focus_segs = [];
    end

    if isempty(Raster) || ~islogical(Raster)
        warning('Raster vide ou invalide.');
        return;
    end

    [nC, T] = size(Raster);

    fR = figure('Name','Raster (pics détectés)','Color','w');
    ax = axes('Parent', fR);
    hold(ax,'on');
    box(ax,'on');

    [cells, frames] = find(Raster);
    scatter(ax, frames, cells, 8, 'k', 'filled');

    xlim(ax,[1 T]);
    ylim(ax,[0.5 nC+0.5]);
    xlabel(ax,'Frames');
    ylabel(ax,'Cellules (valid\_cells)');
    title(ax, sprintf('Raster (%d cellules)', nC));

    if ~isempty(focus_segs)
        yl = ylim(ax);
        for k = 1:size(focus_segs,1)
            a = focus_segs(k,1);
            b = focus_segs(k,2);

            patch(ax, ...
                [a b b a], ...
                [yl(1) yl(1) yl(2) yl(2)], ...
                [1 0 0], ...
                'FaceAlpha',0.18, ...
                'EdgeColor','none', ...
                'HitTest','off');
        end
        uistack(findobj(ax,'Type','patch'),'bottom');
    end
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
            value = round(max(0, value));
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

    setappdata(fig,'auto_intervals', []);
    if isappdata(fig,'seuil_detection_last')
        rmappdata(fig,'seuil_detection_last');
    end

    auto_detect_and_add(fig);
    recompute_n_peaks_all(fig);
    refresh_selection_order(fig);
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