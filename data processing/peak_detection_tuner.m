function peak_detection_tuner(DF, fs, SNR, synchronous_frames)
% GUI CalTrig (interval-based) — annotate Ca2+ transients by [onset, offset]
% Tri des cellules par SNR croissant avec slider pour threshold
%
% Inputs:
%   DF : matrice (n_cells x T) de ΔF/F
%   fs : fréquence d’échantillonnage (Hz)
%   SNR : matrice SNR temporel (n_cells x T)
%   synchronous_frames : nombre de frames pour sommation d'activité synchrone
%
% Outputs:
%   Raster  : matrice binaire (n_cells x T), 1 = pic
%   Acttmp2 : cell array, positions des pics par cellule
%   MAct    : activité multi-cellulaire (somme sur fenêtres)

    % ==== Init ====
    SNR_mean = mean(SNR,2,'omitnan');
    snr_min  = min(SNR_mean);
    snr_max  = max(SNR_mean);
    snr_thr0 = (snr_min + snr_max)/2;

    % ---- Options détection ----
    opts = struct( ...
        'window_size', 3000, ...
        'savgol_win_s', 11, ...
        'savgol_poly', 0, ...
        'min_width_fr', 50, ...
        'prom_sigma', 3.2, ...
        'refrac_fr', 250, ...
        'smooth_disp', 50 ...
    );

    % ---- Figure / Axes ----
    fig = figure('Name','Param Tuner - Cells triées par SNR', ...
        'NumberTitle','off','Position',[100 100 1300 820], 'Color',[.97 .97 .98]);
    set(fig, 'KeyPressFcn', @(~,evnt) navigate_cells(fig, evnt));

    ctrl_panel = uipanel('Parent',fig,'Units','normalized','Position',[0.01 0.05 0.22 0.92], ...
        'Title','Contrôles','FontSize',10,'Tag','ctrl_panel');

    % === Slider SNR threshold ===
    uicontrol('Parent',ctrl_panel,'Style','text','String',sprintf('SNR threshold = %.2f',snr_thr0), ...
        'Units','normalized','Position',[0.05 0.92 0.90 0.04], 'Tag','lbl_snr_thr', ...
        'HorizontalAlignment','left');
    uicontrol('Parent',ctrl_panel,'Style','slider','Min',snr_min,'Max',snr_max, ...
        'Value',snr_thr0,'Units','normalized','Position',[0.05 0.87 0.90 0.04], ...
        'Callback',@(src,~) update_snr_threshold(fig,get(src,'Value')));

    % === Boutons navigation ===
    uicontrol('Parent',ctrl_panel,'Style','pushbutton','String','Cellule suivante', ...
        'Units','normalized','Position',[0.05 0.14 0.90 0.06], ...
        'Callback',@(src,~) next_cell(fig));
    uicontrol('Parent',ctrl_panel,'Style','pushbutton','String','Cellule précédente', ...
        'Units','normalized','Position',[0.05 0.06 0.90 0.06], ...
        'Callback',@(src,~) prev_cell(fig));

    % === Bouton enregistrer ===
    uicontrol('Parent',ctrl_panel,'Style','pushbutton','String','Enregistrer pics', ...
        'Units','normalized','Position',[0.05 0.36 0.90 0.06], ...
        'Callback', @(src,~) save_callback(fig, synchronous_frames));

    % === Contrôles détection ===
    make_slider(ctrl_panel,fig,'Largeur min (fr)','min_width_fr',0,150,opts.min_width_fr,[0.05 0.70 0.90 0.06]);
    make_slider(ctrl_panel,fig,'Prominence (σ)','prom_sigma',0,8,opts.prom_sigma,[0.05 0.64 0.90 0.06]);
    make_slider(ctrl_panel,fig,'Réfractaire (fr)','refrac_fr',0,500,opts.refrac_fr,[0.05 0.58 0.90 0.06]);
    make_slider(ctrl_panel,fig,'Lissage affichage','smooth_disp',0,200,opts.smooth_disp,[0.05 0.52 0.90 0.06]);

    % ---- Axes principal ----
    ax1 = axes('Parent',fig,'Position',[0.28 0.52 0.70 0.41]);
    box(ax1,'on'); xlabel(ax1,'Frames'); ylabel(ax1,'ΔF/F (lissé)');
    plot(ax1,NaN,NaN,'k-'); hold(ax1,'on');

    % ---- Stocker données ---
    setappdata(fig,'DF',DF);
    setappdata(fig,'fs',fs);
    setappdata(fig,'opts',opts);
    setappdata(fig,'ax1',ax1);
    setappdata(fig,'SNR_mean', SNR_mean);
    setappdata(fig,'snr_thr', snr_thr0);

    % Init ordre cellules (déclenche affichage)
    update_snr_threshold(fig,snr_thr0);

    uiwait(fig);

end

%% ===================== DÉTECTION paramétrique =======================
function auto_detect_and_add(fig)
    DF  = getappdata(fig,'DF');
    cid = getappdata(fig,'cell_id');
    opts = getappdata(fig,'opts');

    x = DF(cid,:).';
    Nx = numel(x);
    minithreshold = 0.1;

    % --- Lissage pour détection (identique à l’affichage) ---
    if opts.smooth_disp > 0
        x_s = movmean(x, opts.smooth_disp, 'omitnan');
    else
        x_s = x;
    end

    % --- Seuil bas ---
    baseline = prctile(x_s,5);   % baseline
    sigma    = std(x_s,'omitnan'); 
    thr_lo   = baseline + max([3*sigma, 3*iqr(x_s), minithreshold]);

    % --- Détection des pics initiaux ---
    minW = max(1, round(opts.min_width_fr));
    prom = opts.prom_sigma * std(x_s,'omitnan');

    [~, locs] = findpeaks(x_s, ...
        'MinPeakProminence', prom, ...
        'MinPeakWidth',      minW);

    % Filtrer les pics sous le seuil bas
    locs = locs(x_s(locs) >= thr_lo);

    if isempty(locs)
        setappdata(fig, 'auto_intervals', []);
        setappdata(fig, 'auto_peaks', []);
        setappdata(fig, 'thr_lo_last', thr_lo);
        refresh_data(fig);
        return;
    end

    % --- Déterminer onset/offset ---
    intervals = zeros(numel(locs), 2);
    for i=1:numel(locs)
        pk = locs(i);
        a = pk; while a>1  && x_s(a) > thr_lo, a=a-1; end
        b = pk; while b<Nx && x_s(b) > thr_lo, b=b+1; end
        if (b-a+1) < minW
            d = ceil((minW - (b-a+1))/2);
            a = max(1, a-d); b = min(Nx, b+d);
        end
        intervals(i,:) = [a b];
    end

    % --- Fusion réfractaire ---
    intervals = sortrows(intervals,1);
    merged = [];
    if ~isempty(intervals)
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
    end

    % --- Choisir un seul pic par intervalle fusionné ---
    locs_merged = [];
    for r=1:size(merged,1)
        in_interval = locs(locs >= merged(r,1) & locs <= merged(r,2));
        if ~isempty(in_interval)
            [~, idx_max] = max(x_s(in_interval));
            pk = in_interval(idx_max);
            if x_s(pk) > thr_lo
                locs_merged(end+1) = pk; %#ok<AGROW>
            end
        end
    end

    % --- Sauver ---
    setappdata(fig, 'auto_intervals', merged);
    setappdata(fig, 'auto_peaks', locs_merged);
    setappdata(fig, 'thr_lo_last', thr_lo);
    refresh_data(fig);
end

%% ===================== Affichage ============================
function refresh_data(fig)
    DF = getappdata(fig,'DF');
    cell_id = getappdata(fig,'cell_id');
    opts = getappdata(fig,'opts');
    ax = getappdata(fig,'ax1');
    cla(ax);

    x = DF(cell_id,:).';
    t = 1:numel(x);

    % Signal affiché = identique au signal de détection
    if opts.smooth_disp > 0
        sig_show = movmean(x, opts.smooth_disp, 'omitnan');
    else
        sig_show = x;
    end

    plot(ax,t,sig_show,'k-'); hold(ax,'on');
    xlabel(ax,'Frames'); ylabel(ax,'ΔF/F');

    % Astérisques aux pics détectés
    if isappdata(fig,'auto_peaks')
        auto_peaks = getappdata(fig,'auto_peaks');
        if ~isempty(auto_peaks)
            plot(ax, auto_peaks, sig_show(auto_peaks), 'r*', 'MarkerSize', 8, 'LineWidth',1.2);
        end
    end

    % Ligne seuil bas
    if isappdata(fig,'thr_lo_last')
        thr_lo = getappdata(fig,'thr_lo_last');
        plot(ax,[t(1) t(end)],[thr_lo thr_lo],':','Color',[.7 .1 .1],'LineWidth',1);
    end
end

%% ===================== SAVE PEAK MATRIX ====================
function [Raster, Acttmp2, MAct, thresholds, opts] = save_peak_matrix(fig, synchronous_frames)
    % --- Récupération des données et paramètres du GUI ---
    DF   = getappdata(fig,'DF');
    opts = getappdata(fig,'opts');   % paramètres courants du GUI
    nCells = size(DF,1);
    Nz     = size(DF,2);

    % Initialisation
    Raster     = false(nCells, Nz);
    Acttmp2    = cell(nCells,1);
    thresholds = nan(nCells,1);   % seuil bas par cellule
    minithreshold = 0.1;

    % --- Boucle sur chaque cellule ---
    for cid = 1:nCells
        x = DF(cid,:).';

        % --- Lissage (lié au GUI : opts.savgol_win_s) ---
        x_s = x;
        if opts.savgol_win_s > 0
            sgN = max(opts.savgol_poly+2, round(opts.savgol_win_s));
            if mod(sgN,2)==0, sgN=sgN+1; end
            try
                x_s = sgolayfilt(x, round(opts.savgol_poly), sgN);
            catch
            end
        end

        % --- Seuil bas : max entre 3*IQR, 3*STD et minithreshold ---
        thr_lo = max([3*iqr(x_s), 3*std(x_s,'omitnan'), minithreshold]);
        thresholds(cid) = thr_lo;   % stocker

        % --- Détection stricte ---
        minW = max(1, round(opts.min_width_fr));
        prom = opts.prom_sigma * std(x_s,'omitnan');

        [~, locs] = findpeaks(x_s, ...
            'MinPeakProminence', prom, ...
            'MinPeakWidth',      minW);

        % Filtrer les pics en dessous du seuil bas
        locs = locs(x_s(locs) > thr_lo);

        if isempty(locs)
            Acttmp2{cid} = [];
            continue;
        end

        % --- Déterminer onset/offset ---
        intervals = zeros(numel(locs),2);
        for i=1:numel(locs)
            pk = locs(i);
            a = pk; while a>1  && x_s(a) > thr_lo, a=a-1; end
            b = pk; while b<Nz && x_s(b) > thr_lo, b=b+1; end
            if (b-a+1) < minW
                d = ceil((minW - (b-a+1))/2);
                a = max(1, a-d); b = min(Nz, b+d);
            end
            intervals(i,:) = [a b];
        end

        % --- Fusion réfractaire ---
        intervals = sortrows(intervals,1);
        merged = [];
        if ~isempty(intervals)
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
        end

        % --- Choisir un seul pic par intervalle fusionné ---
        locs_merged = [];
        for r=1:size(merged,1)
            in_interval = locs(locs >= merged(r,1) & locs <= merged(r,2));
            if ~isempty(in_interval)
                [~, idx_max] = max(x_s(in_interval));
                locs_merged(end+1) = in_interval(idx_max); %#ok<AGROW>
            end
        end

        % --- Stockage ---
        Acttmp2{cid} = locs_merged;     % positions des pics
        Raster(cid, locs_merged) = 1;   % marquer dans la matrice
    end

    % --- Activité multi-cellules (MAct) ---
    MAct = zeros(1, Nz - synchronous_frames);
    for i = 1:(Nz - synchronous_frames)
        MAct(i) = sum(max(Raster(:, i:i+synchronous_frames), [], 2));
    end

    % --- Tracer MAct ---
    figure('Name','Multi-cell activity','NumberTitle','off');
    plot(MAct,'k','LineWidth',1.2);
    xlabel('Frame');
    ylabel(sprintf('Active cells in %d-frame window', synchronous_frames));
    title('Synchronous activity (MAct)');
    grid on;
end


%% ===================== UPDATE SNR THRESHOLD ======================
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

    % trier par SNR croissant
    [~, ord] = sort(SNR_mean(valid_cells),'ascend');
    order_cells = valid_cells(ord);

    % mettre à jour
    setappdata(fig,'order_cells', order_cells);
    setappdata(fig,'cell_index_in_order', 1);
    setappdata(fig,'cell_id', order_cells(1));
    setappdata(fig,'snr_thr', thr);
    setappdata(fig,'auto_intervals', []);
    if isappdata(fig,'thr_lo_last'), rmappdata(fig,'thr_lo_last'); end

    % mise à jour affichage
    auto_detect_and_add(fig);
    refresh_data(fig);
end

%% ===================== NAVIGATION ======================
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

%% ===================== Sliders ======================================
function make_slider(parent,fig,label,field,minv,maxv,val,pos)
    intFields = {'savgol_win_s','min_width_fr','refrac_fr'};
    if ismember(field,intFields)
        val = round(max(minv, min(maxv, val)));
        fmt = '%s = %d';
    else
        val = max(minv, min(maxv, val));  % flottant
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
    intFields = {'savgol_win_s','min_width_fr','refrac_fr'};
    if ismember(field,intFields)
        if strcmp(field,'savgol_win_s')
            value = max(1, min(200, round(value)));
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
        if ismember(field,intFields)
            lbl.String = sprintf('%s = %d', lbl.String(1:strfind(lbl.String,'=')-2), value);
        else
            lbl.String = sprintf('%s = %.2f', lbl.String(1:strfind(lbl.String,'=')-2), value);
        end
    end

    % auto-détection + affichage directement quand on change un slider
    auto_detect_and_add(fig);
    refresh_data(fig);
end

function save_callback(fig, synchronous_frames)
    [Raster, Acttmp2, MAct, thresholds, opts] = save_peak_matrix(fig, synchronous_frames);

    % Donner les noms que ton pipeline attend
    assignin('base','Raster', Raster);
    assignin('base','Acttmp2', Acttmp2);
    assignin('base','MAct', MAct);
    assignin('base','thresholds', thresholds);
    assignin('base','opts_used', opts);
end
