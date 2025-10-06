function [DF, baseline_F, noise_est, SNR, DF_sg, Raster, Acttmp2, MAct, thresholds] = ...
    peak_detection_tuner(F, fs, synchronous_frames, varargin)
% GUI CalTrig — interactive tuning and saving of Ca²⁺ transient detection
%
% Inputs:
%   F   : raw fluorescence (n_cells x T)
%   fs  : sampling rate (Hz)
%   synchronous_frames : fenêtre pour activité synchrone
%   'nogui', true      : (optionnel) bypass GUI et lancer détection directe
%
% Outputs:
%   DF, DF_sg, baseline_F, noise_est, SNR : preprocessing
%   Raster, Acttmp2, MAct, thresholds     : détection de pics

    % ---- Options détection (valeurs initiales) ----
    opts = struct( ...
        'window_size', 2000, ...
        'savgol_win', 9, ...
        'savgol_poly', 3, ...
        'min_width_fr', 6, ...
        'prominence_factor', 6, ...
        'refrac_fr', 3 ...
    );

    % Vérifie si mode batch/no-GUI
    nogui = false;
    if ~isempty(varargin)
        for i=1:2:numel(varargin)
            if strcmpi(varargin{i},'nogui')
                nogui = varargin{i+1};
            end
        end
    end

    % --- Prétraitement ---
    [DF, DF_sg, baseline_F, noise_est, SNR, SNR_mean, snr_min, snr_max, snr_thr0] = DF_processing(F, opts);

    % === MODE BATCH (pas de GUI) ===
    if nogui
        % Crée une fig cachée pour utiliser save_peak_matrix
        fig = figure('Visible','off');
        setappdata(fig,'DF_sg',DF_sg);
        setappdata(fig,'opts',opts);
        setappdata(fig,'noise_est',noise_est);
        setappdata(fig,'baseline_F',baseline_F);

        [Raster, Acttmp2, MAct, thresholds, ~] = save_peak_matrix(fig, synchronous_frames);

        if ishghandle(fig), delete(fig); end
        return;
    end

    % === MODE INTERACTIF (GUI) ===
    fig = figure('Name','Param Tuner - Cells triées par SNR', ...
        'NumberTitle','off','Position',[100 100 1300 820], 'Color',[.97 .97 .98]);
    set(fig,'KeyPressFcn', @(~,evnt) navigate_cells(fig, evnt));
    set(fig,'CloseRequestFcn',@(src,~) uiresume(src));

    ctrl_panel = uipanel('Parent',fig,'Units','normalized','Position',[0.01 0.05 0.22 0.92], ...
        'Title','Contrôles','FontSize',10,'Tag','ctrl_panel');

    % --- Slider SNR threshold ---
    uicontrol('Parent',ctrl_panel,'Style','text','String',sprintf('SNR threshold = %.2f',snr_thr0), ...
        'Units','normalized','Position',[0.05 0.92 0.90 0.04], 'Tag','lbl_snr_thr', ...
        'HorizontalAlignment','left');

    uicontrol('Parent',ctrl_panel,'Style','slider','Min',snr_min,'Max',snr_max, ...
        'Value',snr_thr0,'Units','normalized','Position',[0.05 0.87 0.90 0.04], ...
        'Tag','sldr_snr_thr', ...
        'Callback',@(src,~) update_snr_threshold(fig,get(src,'Value')));

    % --- Navigation ---
    uicontrol('Parent',ctrl_panel,'Style','pushbutton','String','Cellule suivante', ...
        'Units','normalized','Position',[0.05 0.14 0.90 0.06], ...
        'Callback',@(src,~) next_cell(fig));
    uicontrol('Parent',ctrl_panel,'Style','pushbutton','String','Cellule précédente', ...
        'Units','normalized','Position',[0.05 0.06 0.90 0.06], ...
        'Callback',@(src,~) prev_cell(fig));

    % --- Enregistrer ---
    uicontrol('Parent',ctrl_panel,'Style','pushbutton','String','Enregistrer pics', ...
        'Units','normalized','Position',[0.05 0.36 0.90 0.06], ...
        'Callback', @(src,~) save_callback(fig, synchronous_frames));

    % --- Exclure l’enregistrement ---
    uicontrol('Parent',ctrl_panel,'Style','pushbutton','String','Exclure enregistrement', ...
        'Units','normalized','Position',[0.05 0.28 0.90 0.06], ...
        'BackgroundColor',[0.85 0.3 0.3], 'ForegroundColor','w', 'FontWeight','bold', ...
        'Callback', @(src,~) exclude_recording(fig));

    % --- Contrôles détection ---
    make_slider(ctrl_panel,fig,'Largeur min (fr)','min_width_fr',0,50,opts.min_width_fr,[0.05 0.70 0.90 0.06]);
    make_slider(ctrl_panel,fig,'Prominence','prominence_factor',0,10,opts.prominence_factor,[0.05 0.64 0.90 0.06]);
    make_slider(ctrl_panel,fig,'Réfractaire (fr)','refrac_fr',0,10,opts.refrac_fr,[0.05 0.58 0.90 0.06]);
    make_slider(ctrl_panel,fig,'SavGol window','savgol_win',3,51,opts.savgol_win,[0.05 0.52 0.90 0.06]);

    % ---- Axe principal ----
    ax1 = axes('Parent',fig,'Position',[0.28 0.52 0.70 0.41]);
    box(ax1,'on'); xlabel(ax1,'Frames'); ylabel(ax1,'ΔF/F (SavGol)');
    plot(ax1,NaN,NaN,'k-'); hold(ax1,'on');

    % ---- Stocker données ----
    setappdata(fig,'fs',fs);
    setappdata(fig,'F_raw',F);
    setappdata(fig,'DF',DF);
    setappdata(fig,'DF_sg',DF_sg);
    setappdata(fig,'baseline_F',baseline_F);
    setappdata(fig,'noise_est',noise_est);
    setappdata(fig,'SNR',SNR);
    setappdata(fig,'opts',opts);
    setappdata(fig,'SNR_mean',SNR_mean);
    setappdata(fig,'ax1',ax1);

    % Init ordre cellules + affichage
    update_snr_threshold(fig,snr_thr0);

    uiwait(fig);

    % ---- Sorties GUI ----
    if isappdata(fig,'excluded') && getappdata(fig,'excluded')
        % Si exclu -> tout vide
        disp('Enregistrement exclu — aucune donnée sauvegardée.');
        Raster     = [];
        Acttmp2    = [];
        MAct       = [];
        thresholds = [];
    elseif ishghandle(fig) && isappdata(fig,'last_save_outputs')
        out = getappdata(fig,'last_save_outputs');
        Raster     = out.Raster;
        Acttmp2    = out.Acttmp2;
        MAct       = out.MAct;
        thresholds = out.thresholds;
    else
        Raster     = false(size(DF));
        Acttmp2    = repmat({[]}, size(DF,1),1);
        MAct       = [];
        thresholds = nan(size(DF,1),1);
    end
    
    if ishghandle(fig)
        delete(fig);
    end

end


%% ===================== DF PROCESSING (unique) =======================
function [DF, DF_sg, baseline_F, noise_est, SNR, SNR_mean, snr_min, snr_max, snr_thr0] = DF_processing(F, opts)
    % Calcule DF, baseline, SavGol (DF_sg), bruit (rolling) et SNR.
    %
    % Seuls opts.window_size, opts.savgol_win, opts.savgol_poly sont utilisés ici.

    percentile   = 5;
    window_size  = opts.window_size;
    sg_win       = opts.savgol_win;     % sera forçé impair ci-dessous
    sg_poly      = opts.savgol_poly;
    noise_window = 20;                  % frames
    noise_method = 'mean';
    snr_min_cap  = 0.1;

    [NCell, Nz] = size(F);

    % --- Step 1: ΔF/F & baseline ---
    DF = nan(NCell, Nz);
    baseline_F = nan(NCell, 1);
    for n = 1:NCell
        trace = F(n,:);
        F0 = nan(Nz,1);

        num_blocks = ceil(Nz / window_size);
        for i = 1:num_blocks
            a = (i-1)*window_size + 1;
            b = min(i*window_size, Nz);
            F0(a:b) = prctile(trace(a:b), percentile);
        end
        F0 = movmedian(F0, window_size, 'omitnan');
        F0 = smoothdata(F0, 1, 'gaussian', window_size/2);

        baseline_F(n) = mean(F0, 'omitnan');
        DF(n,:) = (trace - F0') ./ F0';
    end

    % --- Step 2: SavGol + bruit ---
    DF_sg     = nan(NCell, Nz);
    noise_est = nan(NCell, Nz);

    % s'assurer que la fenêtre SavGol est impaire et suffisante
    sgN = max(sg_poly+2, round(sg_win));
    if mod(sgN,2)==0, sgN = sgN+1; end

    for n = 1:NCell
        sig = DF(n,:);
        try
            sig_sg = sgolayfilt(sig, sg_poly, sgN);
        catch
            sig_sg = sig;
        end
        DF_sg(n,:) = sig_sg;

        raw_noise = abs(sig - sig_sg);
        switch noise_method
            case 'mean',   noise_est(n,:) = movmean(raw_noise,  noise_window);
            case 'median', noise_est(n,:) = movmedian(raw_noise,noise_window);
            case 'max',    noise_est(n,:) = movmax(raw_noise,   noise_window);
        end
    end

    % --- Step 3: SNR ---
    noise_est(noise_est < snr_min_cap) = snr_min_cap;
    SNR = DF_sg ./ noise_est;

    % --- Stats SNR pour GUI ---
    SNR_mean = mean(SNR,2,'omitnan');
    snr_min  = min(SNR_mean);
    snr_max  = max(SNR_mean);
    snr_thr0 = (snr_min + snr_max)/2;
end

%% ===================== AUTO DETECT =======================
function auto_detect_and_add(fig)
    DF_sg   = getappdata(fig,'DF_sg');       % ΔF/F lissé SavGol
    cid     = getappdata(fig,'cell_id');     % cellule en cours
    opts    = getappdata(fig,'opts');        % paramètres GUI
    noise_est    = getappdata(fig,'noise_est');        % paramètres GUI

    x  = DF_sg(cid,:).';
    Nx = numel(x);
    minithreshold = 0.1;
    
    sigma = mean(noise_est(cid,:), 'omitnan');   % bruit estimé
    prominence = opts.prominence_factor * sigma;
    thr_lo = max([3 * iqr(x), 3 * std(x), minithreshold]);
    
    % --- Détection stricte (seuil intégré directement) ---
    minW = max(1, round(opts.min_width_fr));
    [~, locs] = findpeaks(x, ...
        'MinPeakProminence', prominence, ...
        'MinPeakHeight',     thr_lo, ...
        'MinPeakWidth',      minW);

    if isempty(locs)
        setappdata(fig,'auto_intervals',[]);
        setappdata(fig,'auto_peaks',[]);
        setappdata(fig,'thr_lo_last',thr_lo);
        refresh_data(fig);
        return;
    end

    % Déterminer onset/offset
    intervals = zeros(numel(locs),2);
    for i = 1:numel(locs)
        pk = locs(i);
    
        % Étendre vers la gauche jusqu’à baseline
        a = pk;
        while a > 1 && x(a) > thr_lo
            a = a - 1;
        end
    
        % Étendre vers la droite jusqu’à baseline
        b = pk;
        while b < Nx && x(b) > thr_lo
            b = b + 1;
        end
    
        % Assurer largeur minimale
        if (b - a + 1) < minW
            d = ceil((minW - (b - a + 1))/2);
            a = max(1, a - d);
            b = min(Nx, b + d);
        end
    
        intervals(i,:) = [a b];
    end

    % Fusion réfractaire
    intervals = sortrows(intervals,1);
    merged = [];
    cur = intervals(1,:); gap = max(0, round(opts.refrac_fr));
    for i=2:size(intervals,1)
        if intervals(i,1) <= cur(2) + gap
            cur(2) = max(cur(2), intervals(i,2));
        else
            merged = [merged; cur]; %#ok<AGROW>
            cur = intervals(i,:);
        end
    end
    merged = [merged; cur];

    % Un seul pic par intervalle fusionné
    locs_merged = [];
    for r=1:size(merged,1)
        in_interval = locs(locs >= merged(r,1) & locs <= merged(r,2));
        if ~isempty(in_interval)
            [~, idx_max] = max(x(in_interval));
            pk = in_interval(idx_max);
            if x(pk) >= thr_lo
                locs_merged(end+1) = pk; %#ok<AGROW>
            end
        end
    end

    setappdata(fig,'auto_intervals',merged);
    setappdata(fig,'auto_peaks',locs_merged);
    setappdata(fig,'thr_lo_last',thr_lo);
    refresh_data(fig);
end

%% ===================== AFFICHAGE =======================

function refresh_data(fig)
    DF_sg   = getappdata(fig,'DF_sg');   % ΔF/F lissé SavGol
    cell_id = getappdata(fig,'cell_id');
    ax      = getappdata(fig,'ax1');
    cla(ax);

    x = DF_sg(cell_id,:);   % 1 x T (ou 1x0 si vide)
    x = x(:).';             % force en ligne
    T = numel(x);
    t = 1:T;                % même longueur que x
    xlim(ax,[1 T]);

    % Tracé du signal
    plot(ax,t,x,'k-'); hold(ax,'on');
    xlabel(ax,'Frames'); ylabel(ax,'ΔF/F (SavGol)');

    % --- Pics détectés ---
    if isappdata(fig,'auto_peaks')
        auto_peaks = getappdata(fig,'auto_peaks');
        if ~isempty(auto_peaks)
            % garde uniquement ceux dans [1,T]
            auto_peaks = auto_peaks(auto_peaks>=1 & auto_peaks<=T);
            if ~isempty(auto_peaks)
                plot(ax, auto_peaks, x(auto_peaks), ...
                    'r*','MarkerSize',8,'LineWidth',1.2);
            end
        end
    end

    % --- Ligne seuil bas ---
    if isappdata(fig,'thr_lo_last')
        thr_lo = getappdata(fig,'thr_lo_last');
        if isfinite(thr_lo)
            plot(ax,[1 T],[thr_lo thr_lo],':','Color',[.7 .1 .1],'LineWidth',1);
        end
    end
end

%% ===================== SAVE PEAK MATRIX =======================
function [Raster, Acttmp2, MAct, thresholds, opts] = save_peak_matrix(fig, synchronous_frames)
    DF_sg   = getappdata(fig,'DF_sg');
    opts    = getappdata(fig,'opts');
    noise_est = getappdata(fig,'noise_est');
    nCells = size(DF_sg,1);
    Nz     = size(DF_sg,2);

    Raster     = false(nCells, Nz);
    Acttmp2    = cell(nCells,1);
    thresholds = nan(nCells,1);
    minithreshold = 0.1;

    for cid = 1:nCells
        x  = DF_sg(cid,:).';   % signal pour détection
        Nx = numel(x);

        sigma = mean(noise_est(cid,:), 'omitnan');   % bruit estimé
        prominence = opts.prominence_factor * sigma;
        thr_lo = max([3 * iqr(x), 3 * std(x), minithreshold]);
        
        % --- Détection stricte (seuil intégré directement) ---
        minW = max(1, round(opts.min_width_fr));
        [~, locs] = findpeaks(x, ...
            'MinPeakProminence', prominence, ...
            'MinPeakHeight',     thr_lo, ...
            'MinPeakWidth',      minW);

        if isempty(locs), Acttmp2{cid} = []; continue; end

        % onset/offset
        intervals = zeros(numel(locs),2);
        for i = 1:numel(locs)
            pk = locs(i);
        
            % Étendre vers la gauche jusqu’à thr_lo
            a = pk;
            while a > 1 && x(a) > thr_lo
                a = a - 1;
            end
        
            % Étendre vers la droite jusqu’à thr_lo
            b = pk;
            while b < Nx && x(b) > thr_lo
                b = b + 1;
            end
        
            % Assurer largeur minimale
            if (b - a + 1) < minW
                d = ceil((minW - (b - a + 1))/2);
                a = max(1, a - d);
                b = min(Nx, b + d);
            end
        
            intervals(i,:) = [a b];
        end


        % fusion réfractaire
        intervals = sortrows(intervals,1);
        merged = [];
        cur = intervals(1,:); gap = max(0, round(opts.refrac_fr));
        for i=2:size(intervals,1)
            if intervals(i,1) <= cur(2) + gap
                cur(2) = max(cur(2), intervals(i,2));
            else
                merged = [merged; cur]; %#ok<AGROW>
                cur = intervals(i,:);
            end
        end
        merged = [merged; cur];

        % un pic par intervalle
        locs_merged = [];
        for r=1:size(merged,1)
            in_interval = locs(locs >= merged(r,1) & locs <= merged(r,2));
            if ~isempty(in_interval)
                [~, idx_max] = max(x(in_interval));
                pk = in_interval(idx_max);
                if x(pk) >= thr_lo
                    locs_merged(end+1) = pk; %#ok<AGROW>
                end
            end
        end

        Acttmp2{cid} = locs_merged;
        Raster(cid, locs_merged) = 1;
        thresholds(cid) = thr_lo;
    end

    % activité multi-cellules
    if Nz > synchronous_frames
        MAct = zeros(1, Nz - synchronous_frames);
        for i = 1:(Nz - synchronous_frames)
            MAct(i) = sum(max(Raster(:, i:i+synchronous_frames), [], 2));
        end
    else
        MAct = zeros(1,0);
    end

    % trace MAct
    % figure('Name','Multi-cell activity','NumberTitle','off');
    % plot(MAct,'k','LineWidth',1.2);
    % xlabel('Frame');
    % ylabel(sprintf('Active cells in %d-frame window', synchronous_frames));
    % title('Synchronous activity (MAct)');
    % grid on;
end

%% ===================== SNR THRESHOLD / TRI =======================
function update_snr_threshold(fig, thr)
    SNR_mean = getappdata(fig,'SNR_mean');
    valid_cells = find(SNR_mean >= thr);

    lbl = findobj(fig,'Tag','lbl_snr_thr');
    if ~isempty(lbl), lbl.String = sprintf('SNR threshold = %.2f',thr); end

    ax = getappdata(fig,'ax1');

    if isempty(valid_cells)
        setappdata(fig,'order_cells', []);
        setappdata(fig,'cell_index_in_order', []);
        cla(ax);
        title(ax, sprintf('Aucune cellule avec SNR >= %.2f',thr));
        drawnow;
        return;
    end

    [~, ord] = sort(SNR_mean(valid_cells),'ascend');
    order_cells = valid_cells(ord);

    setappdata(fig,'order_cells', order_cells);
    setappdata(fig,'cell_index_in_order', 1);
    setappdata(fig,'cell_id', order_cells(1));
    setappdata(fig,'snr_thr', thr);
    setappdata(fig,'auto_intervals', []);
    if isappdata(fig,'thr_lo_last'), rmappdata(fig,'thr_lo_last'); end

    auto_detect_and_add(fig);
    refresh_data(fig);
end

%% ===================== NAVIGATION =======================
function next_cell(fig)
    order_cells = getappdata(fig,'order_cells');
    if isempty(order_cells), return; end
    cur_idx = getappdata(fig,'cell_index_in_order');
    if isempty(cur_idx), cur_idx = 1; end
    if cur_idx < numel(order_cells), cur_idx = cur_idx + 1; end
    setappdata(fig,'cell_index_in_order', cur_idx);
    setappdata(fig,'cell_id', order_cells(cur_idx));
    setappdata(fig,'auto_intervals', []);
    if isappdata(fig,'thr_lo_last'), rmappdata(fig,'thr_lo_last'); end
    auto_detect_and_add(fig);
    refresh_data(fig);
end

function prev_cell(fig)
    order_cells = getappdata(fig,'order_cells');
    if isempty(order_cells), return; end
    cur_idx = getappdata(fig,'cell_index_in_order');
    if isempty(cur_idx), cur_idx = 1; end
    if cur_idx > 1, cur_idx = cur_idx - 1; end
    setappdata(fig,'cell_index_in_order', cur_idx);
    setappdata(fig,'cell_id', order_cells(cur_idx));
    setappdata(fig,'auto_intervals', []);
    if isappdata(fig,'thr_lo_last'), rmappdata(fig,'thr_lo_last'); end
    auto_detect_and_add(fig);
    refresh_data(fig);
end

function navigate_cells(fig, evnt)
    switch evnt.Key
        case 'rightarrow', next_cell(fig);
        case 'leftarrow',  prev_cell(fig);
    end
end

%% ===================== SLIDERS =======================
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
    intFields = {'savgol_win','min_width_fr','refrac_fr'};
    if ismember(field,intFields)
        if strcmp(field,'savgol_win')
            value = round(value);
            if value < 3, value = 3; end
            if mod(value,2)==0, value = value+1; end % imposer impair
        else
            value = round(max(0, value));
        end
    else
        value = max(0, value);
    end
    opts.(field) = value;
    setappdata(fig,'opts',opts);

    % MAJ label
    lbl = findobj(fig,'Tag',['lbl_' field]);
    if ~isempty(lbl)
        if ismember(field,intFields)
            lbl.String = sprintf('%s = %d', lbl.String(1:strfind(lbl.String,'=')-2), value);
        else
            lbl.String = sprintf('%s = %.2f', lbl.String(1:strfind(lbl.String,'=')-2), value);
        end
    end

    % Si savgol_win change: recalcul DF_sg, noise, SNR + MAJ slider SNR
    if strcmp(field,'savgol_win')
        F_raw = getappdata(fig,'F_raw');
        [DF, DF_sg, baseline_F, noise_est, SNR, SNR_mean, snr_min, snr_max, snr_thr0] = DF_processing(F_raw, opts);

        setappdata(fig,'DF', DF);
        setappdata(fig,'DF_sg', DF_sg);
        setappdata(fig,'baseline_F', baseline_F);
        setappdata(fig,'noise_est', noise_est);
        setappdata(fig,'SNR', SNR);
        setappdata(fig,'SNR_mean', SNR_mean);

        sldr = findobj(fig,'Tag','sldr_snr_thr');
        if ~isempty(sldr)
            sldr.Min   = snr_min;
            sldr.Max   = snr_max;
            sldr.Value = snr_thr0;
        end
        sLbl = findobj(fig,'Tag','lbl_snr_thr');
        if ~isempty(sLbl)
            sLbl.String = sprintf('SNR threshold = %.2f', snr_thr0);
        end
    end

    auto_detect_and_add(fig);
    refresh_data(fig);
end

%% ===================== SAVE CALLBACK =======================
function save_callback(fig, synchronous_frames)
    [Raster, Acttmp2, MAct, thresholds, opts] = save_peak_matrix(fig, synchronous_frames);

    % reshape avant stockage
    if iscell(Acttmp2) && size(Acttmp2,2) > 1
        Acttmp2 = reshape(Acttmp2, [], 1);
    end

    setappdata(fig,'last_save_outputs', struct( ...
        'Raster', Raster, 'Acttmp2', {Acttmp2}, 'MAct', MAct, ...
        'thresholds', thresholds, 'opts', opts));

    % assignin('base','Raster',      Raster);
    % assignin('base','Acttmp2',     Acttmp2);
    % assignin('base','MAct',        MAct);
    % assignin('base','thresholds',  thresholds);
    % assignin('base','opts_used',   opts);

    if ishghandle(fig), uiresume(fig); close(fig); end
end

function exclude_recording(fig)
    % Fonction appelée quand on clique sur "Exclure enregistrement"
    disp('Enregistrement exclu par l’utilisateur.');
    
    % Stocke un flag dans les appdata
    setappdata(fig, 'excluded', true);
    
    % Ferme proprement le GUI
    if ishghandle(fig)
        uiresume(fig);
        close(fig);
    end
end
