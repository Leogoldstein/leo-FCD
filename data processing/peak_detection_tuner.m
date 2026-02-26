function [DF, F0, noise_est, SNR, valid_cells, DF_sg, Raster, Acttmp2, StartEnd, MAct, thresholds, focus_segs] = ...
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
%   DF, DF_sg, F0, noise_est, SNR : preprocessing
%   Raster, Acttmp2, MAct, thresholds     : détection de pics

    % ---- Options détection (valeurs initiales) ----
    opts = struct( ...
        'window_size', 2000, ...
        'savgol_win', 9, ...
        'savgol_poly', 3, ...
        'min_width_fr', 6, ...
        'prominence_factor', 6.6, ...
        'refrac_fr', 3 ...
    );

    % Vérifie si mode batch/no-GUI
    nogui = false;
    fall_path = '';
    corrXY = [];
    iscell_in = [];
    stat_in   = [];
    
    if ~isempty(varargin)
    
        % Si nombre impair -> on ignore le dernier
        if mod(numel(varargin),2) ~= 0
            warning('peak_detection_tuner:varargin', ...
                    'varargin doit être en paires clé/valeur. Dernier argument ignoré.');
            varargin = varargin(1:end-1);
        end
    
        for i = 1:2:numel(varargin)
            key = varargin{i};
    
            % clé doit être char ou string
            if ~(ischar(key) || (isstring(key) && isscalar(key)))
                warning('peak_detection_tuner:badKey', ...
                        'Clé varargin #%d invalide (type %s). Paire ignorée.', i, class(key));
                continue;
            end
   
            val = varargin{i+1};
    
            switch key
                case 'nogui'
                    nogui = logical(val);
    
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
                    meanImg = val;   % optionnel si tu l’as

                case 'gcamp_TSeries_path'
                    gcamp_TSeries_path = val;

                case 'speed'
                    speed = val;
            end
        end
    end


    % --- Prétraitement ---
    [DF, DF_sg, F0, noise_est, SNR, quality_index, quality_rank, quality_min, quality_max, quality_thr0] = DF_processing(F, opts, fs);

    [deviation, bad_frames, bad_frames_not_active, bad_frames_active] = motion_correction_substraction(DF_sg, ops, speed);
    deviation = deviation(:).';  % force row
    bad_frames_active = bad_frames_active(:)';
    bad_segs = badframes_to_segments(bad_frames_active, size(DF_sg,2));   % Nx2 
    
    segTable = sort_segments_by_deviation(bad_segs, deviation);
    assignin('base', 'segTable', segTable);

    T = size(DF_sg,2);
    [user_focus_segs, user_focus_frames] = enter_observed_deviations(gcamp_TSeries_path, T);
    
    if ~isempty(user_focus_segs)
        focus_segs = user_focus_segs;
    else
        focus_segs = bad_segs;
    end
            
    % focus_segs = segments bad confirmés comme focus change
    % focus_labels(k)=1 focus, 0 autre, NaN skip

    % === MODE BATCH (pas de GUI) ===
    if nogui
        fig = figure('Visible','off'); % fig cachée pour utiliser appdata
        setappdata(fig,'DF_sg',DF_sg);
        setappdata(fig,'opts',opts);
        setappdata(fig,'noise_est',noise_est);
        setappdata(fig,'F0',F0);
        setappdata(fig,'quality_index', quality_index);   % pour couleur/affichage
        setappdata(fig,'quality_rank',  quality_rank);    % pour tri + seuil
        setappdata(fig,'deviation', deviation);
        setappdata(fig,'bad_frames', bad_frames);
        setappdata(fig,'focus_segs', focus_segs);
        setappdata(fig,'cell_status', zeros(size(F,1),1));
        setappdata(fig,'iscell', iscell_in);
        setappdata(fig,'stat',   stat_in);

        [~, valid_cells, DF_sg, F0, Raster, Acttmp2, StartEnd, MAct, thresholds, ~, summary] = ...
            save_peak_matrix(fig, synchronous_frames);

        % récapitulatif console
        if ~isempty(summary)
            fprintf('\n===== RÉCAPITULATIF SÉLECTION CELLULES =====\n');
            fprintf('Total cellules             : %d\n', summary.n_total);
            fprintf('Cellules finales (analysées): %d\n', summary.n_kept_final);
            fprintf('Qualité moyenne (toutes)    : %.3f\n', summary.mean_quality_all);
            fprintf('Qualité moyenne (finales)   : %.3f\n', summary.mean_quality_kept_final);
            fprintf('===========================================\n\n');
        end

        if ishghandle(fig), delete(fig); end
        return;
    end

    % === MODE INTERACTIF (GUI) ===
    fig = figure('Name','Param Tuner - Cells triées par Qualité', ...
        'NumberTitle','off','Position',[100 100 1300 820], 'Color',[.97 .97 .98]);
    set(fig,'KeyPressFcn', @(~,evnt) navigate_cells(fig, evnt));
    set(fig,'CloseRequestFcn',@(src,~) uiresume(src)); % on laisse l'utilisateur fermer, pas de save auto

    ctrl_panel = uipanel('Parent',fig,'Units','normalized','Position',[0.01 0.05 0.22 0.92], ...
        'Title','Contrôles','FontSize',10,'Tag','ctrl_panel');

    % --- Slider Quality threshold ---
    % --- Slider Rang threshold (basé sur quality_rank) ---
    uicontrol('Parent',ctrl_panel,'Style','text', ...
        'String', sprintf('Rang minimum = %d', quality_thr0), ...
        'Units','normalized','Position',[0.05 0.92 0.90 0.04], ...
        'Tag','lbl_quality_thr','HorizontalAlignment','left');

    step_small = 1/(quality_max - quality_min);
    step_big   = min(1, 10/(quality_max - quality_min));

    uicontrol('Parent',ctrl_panel,'Style','slider', ...
        'Min', quality_min, 'Max', quality_max, 'Value', quality_thr0, ...
        'SliderStep', [step_small step_big], ...
        'Units','normalized','Position',[0.05 0.87 0.90 0.04], ...
        'Tag','sldr_quality_thr', ...
        'Callback', @(src,~) update_quality_threshold(fig, round(get(src,'Value'))));

    % --- Garder / Exclure cellule ---
    uicontrol('Parent',ctrl_panel,'Style','pushbutton','String','Garder cellule', ...
        'Units','normalized','Position',[0.05 0.36 0.90 0.06], ...
        'BackgroundColor',[0.25 0.65 0.25], 'ForegroundColor','w', 'FontWeight','bold', ...
        'Callback', @(src,~) keep_cell(fig));

    uicontrol('Parent',ctrl_panel,'Style','pushbutton','String','Exclure cellule', ...
        'Units','normalized','Position',[0.05 0.28 0.90 0.06], ...
        'BackgroundColor',[0.85 0.3 0.3], 'ForegroundColor','w', 'FontWeight','bold', ...
        'Callback', @(src,~) exclude_cell(fig));

    % --- Étape 1 : sélectionner cellules (filtrage >= seuil) ---
    uicontrol('Parent',ctrl_panel,'Style','pushbutton','String','Seuil de sélection', ...
        'Units','normalized','Position',[0.05 0.10 0.90 0.06], ...
        'BackgroundColor',[0.2 0.45 0.9], 'ForegroundColor','w','FontWeight','bold', ...
        'Callback',@(src,~) enter_selection_mode(fig));
    
    % --- Étape 2 : confirmer (crée réellement les matrices) ---
    uicontrol('Parent',ctrl_panel,'Style','pushbutton','String','Confirmer sélection', ...
        'Units','normalized','Position',[0.05 0.04 0.90 0.06], ...
        'BackgroundColor',[0.1 0.6 0.35], 'ForegroundColor','w','FontWeight','bold', ...
        'Callback',@(src,~) finalize_and_close(fig, synchronous_frames));

    % --- Contrôles détection ---
    make_slider(ctrl_panel,fig,'Largeur min (fr)','min_width_fr',0,50,opts.min_width_fr,[0.05 0.70 0.90 0.06]);
    make_slider(ctrl_panel,fig,'Prominence','prominence_factor',0,10,opts.prominence_factor,[0.05 0.64 0.90 0.06]);
    make_slider(ctrl_panel,fig,'Réfractaire (fr)','refrac_fr',0,10,opts.refrac_fr,[0.05 0.58 0.90 0.06]);
    make_slider(ctrl_panel,fig,'SavGol window','savgol_win',3,51,opts.savgol_win,[0.05 0.52 0.90 0.06]);

    % ---- Axe principal (haut) ----
    ax1 = axes('Parent',fig,'Position',[0.28 0.60 0.70 0.33]); % un peu plus haut
    box(ax1,'on'); xlabel(ax1,'Frames'); ylabel(ax1,'\DeltaF/F (SavGol)');
    plot(ax1,NaN,NaN,'k-'); hold(ax1,'on');

    setappdata(fig,'deviation', deviation);
    setappdata(fig,'bad_frames', bad_frames);
    setappdata(fig,'focus_segs', focus_segs);

    focus_segs = getappdata(fig,'focus_segs');
    if ~isempty(focus_segs)
        hBad1 = create_badframe_patch(ax1, focus_segs);
        setappdata(fig,'hBadPatch_ax1', hBad1);
    end

    axDev = axes('Parent',fig,'Position',[0.28 0.52 0.70 0.07]);
    box(axDev,'on'); ylabel(axDev,'Dev');
    set(axDev,'XTickLabel',[]);
    cla(axDev); hold(axDev,'on');
    
    % trace deviation
    dev = getappdata(fig,'deviation');   % ou directement deviation
    dev = dev(:)'; 
    tDev = 1:numel(dev);
    
    if ~isempty(dev)
        hDev = plot(axDev, tDev, dev, 'k-','HitTest','off');
        setappdata(fig,'hDev', hDev);
    else
        text(axDev,0.5,0.5,'deviation vide','Units','normalized','HorizontalAlignment','center');
    end
    
    % y-lim robuste
    dv = dev(isfinite(dev));
    if ~isempty(dv)
        lo = prctile(dv, 2);
        hi = prctile(dv, 98);
        if isfinite(lo) && isfinite(hi) && hi>lo
            pad = 0.1*(hi-lo);
            ylim(axDev, [lo-pad, hi+pad]);
        end
    end
    
    % patch bad frames (APRES ylim pour avoir la bonne hauteur)
    focus_segs = getappdata(fig,'focus_segs'); % ou variable locale focus_segs
    if ~isempty(focus_segs)
        hBadDev = create_badframe_patch(axDev, focus_segs);
        setappdata(fig,'hBadPatch_axDev', hBadDev);
    end

    % ylim robuste une fois (pour éviter que les patches changent de taille)
    dv = deviation(isfinite(deviation));
    if ~isempty(dv)
        lo = prctile(dv, 2);
        hi = prctile(dv, 98);
        if isfinite(lo) && isfinite(hi) && hi>lo
            pad = 0.1*(hi-lo);
            ylim(axDev, [lo-pad, hi+pad]);
        end
    end

    setappdata(fig,'ax1',ax1);
    setappdata(fig,'axDev',axDev);
    
    % Lier les axes en X (navigation / zoom cohérents)
    linkaxes([ax1 axDev],'x');

    % ---- Axe ROI zoom (bas milieu-gauche, à gauche de l'histogramme) ----
    axROI = axes('Parent',fig,'Position',[0.28 0.08 0.30 0.32]);
    box(axROI,'on');
    title(axROI,'ROI (zoom)');
    axis(axROI,'image');
    setappdata(fig,'axROI', axROI);
    
    % ---- Axe histogramme (bas droite) ----
    axH = axes('Parent',fig,'Position',[0.62 0.08 0.35 0.32]);
    box(axH,'on');
    title(axH,'# pics / cellule');
    xlabel(axH,'Nombre de pics');
    ylabel(axH,'Nombre de cellules');
    setappdata(fig,'axH',axH);

    % ---- Stocker données ----
    setappdata(fig,'fs',fs);
    setappdata(fig,'F_raw',F);
    setappdata(fig,'DF',DF);
    setappdata(fig,'DF_sg',DF_sg);
    setappdata(fig,'F0',F0);
    setappdata(fig,'noise_est',noise_est);
    setappdata(fig,'SNR',SNR);
    setappdata(fig,'opts',opts);
    setappdata(fig,'ax1',ax1);
    setappdata(fig,'quality_index', quality_index);   % pour couleur/affichage
    setappdata(fig,'quality_rank',  quality_rank);    % pour tri + seuil
    setappdata(fig,'quality_min', quality_min);
    setappdata(fig,'quality_max', quality_max);
    setappdata(fig,'quality_thr', quality_thr0);
    setappdata(fig,'axH', axH);
    setappdata(fig,'selection_mode', false);
    if isappdata(fig,'selection_thr_locked')
        rmappdata(fig,'selection_thr_locked'); % évite qu'un lock ancien interfère
    end
    setappdata(fig,'iscell', iscell_in);
    setappdata(fig,'stat',   stat_in);
    setappdata(fig,'meanImg', meanImg);

    % cell_status: 0 undecided, +1 keep, -1 exclude
    nCells = size(F,1);
    setappdata(fig,'cell_status', zeros(size(F,1),1));

    update_quality_threshold(fig, quality_thr0);  % définit cell_id + refresh_data
    recompute_n_peaks_all(fig);
    update_peak_histogram(fig);      

    uiwait(fig);

    % ---- Sorties GUI ----
    if ishghandle(fig) && isappdata(fig,'last_save_outputs')
        out = getappdata(fig,'last_save_outputs');

        valid_cells = out.valid_cells;
        DF_sg      = out.DF_sg;
        F0 = out.F0;
        Raster     = out.Raster;
        Acttmp2    = out.Acttmp2;
        StartEnd   = out.StartEnd;
        MAct       = out.MAct;
        thresholds = out.thresholds;

        % récapitulatif console
        if isfield(out,'summary')
            s = out.summary;
            fprintf('\n===== RÉCAPITULATIF SÉLECTION CELLULES =====\n');
            fprintf('Total cellules             : %d\n', s.n_total);
            fprintf('Cellules finales (analysées): %d\n', s.n_kept_final);
            fprintf('Qualité moyenne (toutes)    : %.3f\n', s.mean_quality_all);
            fprintf('Qualité moyenne (finales)   : %.3f\n', s.mean_quality_kept_final);
            fprintf('===========================================\n\n');
        end
    else
        % rien n'a été finalisé
        Raster     = false(size(DF));
        Acttmp2    = repmat({[]}, size(DF,1),1);
        StartEnd   = repmat({[]}, size(DF,1),1);
        MAct       = [];
        thresholds = nan(size(DF,1),1);
        valid_cells = [];
        DF_sg = [];
        F0 = [];
    end

    if ishghandle(fig)
        delete(fig);
    end
end


%% ===================== DF PROCESSING (unique) =======================
function [DF, DF_sg, F0, noise_est, SNR, quality_index, quality_rank, quality_min, quality_max, quality_thr0] = ...
    DF_processing(F, opts, fs)

% DF_processing — VERSION "NAÏVE" POUR TEST (SANS FENÊTRE GLISSANTE)
% Tri basé uniquement sur une estimation de "bruit" via MAD globale sur la trace lissée (DF_sg),
% puis score = A / noise_sigma (pas de bulk, pas de résidu).
%
% Objectif: vérifier que ce tri est effectivement "moyen" vs résidu+bulk.

    % --------- Params ---------
    sg_win  = opts.savgol_win;
    sg_poly = opts.savgol_poly;

    if nargin < 3 || isempty(fs) || ~isfinite(fs) || fs <= 0
        fs = 20;
    end

    snr_min_cap = 1e-3;

    % --- Step 1: baseline + dF/F ---
    [F0, DF] = baseline_calculation(F);

    [NCell, Nz] = size(DF);

    DF_sg     = nan(NCell, Nz);
    noise_est = nan(NCell, Nz);
    noise_sigma = nan(NCell, 1);   % <--- IMPORTANT: préallocation

    % --- Fenêtre SavGol (impair, <= Nz, > sg_poly) ---
    sgN = max(sg_poly+2, round(sg_win));
    if mod(sgN,2)==0, sgN = sgN+1; end
    if sgN > Nz
        sgN = Nz - (mod(Nz,2)==0); % rend impair si Nz pair
    end
    if sgN <= sg_poly
        sgN = sg_poly + 2;
        if mod(sgN,2)==0, sgN = sgN+1; end
        if sgN > Nz
            sgN = Nz - (mod(Nz,2)==0);
        end
    end

    % --- Step 2: SavGol + "bruit" MAD globale sur DF_sg ---
    for n = 1:NCell
        sig = DF(n,:);

        % SavGol
        sig_sg = sig;
        if all(isfinite(sig)) && sgN >= (sg_poly+2) && sgN <= Nz
            try
                sig_sg = sgolayfilt(sig, sg_poly, sgN);
            catch
                sig_sg = sig;
            end
        end
        DF_sg(n,:) = sig_sg;

        % ===== Bruit NAÏF : MAD globale sur la trace lissée =====
        x = sig_sg;
        m = median(x, 'omitnan');
        ns = 1.4826 * median(abs(x - m), 'omitnan');

        if ~isfinite(ns) || ns < snr_min_cap
            ns = snr_min_cap;
        end
        noise_sigma(n,1) = ns;

        % pour compat avec le reste du code : bruit constant dans le temps
        noise_est(n,:) = ns;
    end

    % --- Amplitude robuste des "pics" ---
    A = prctile(DF_sg, 99.5, 2) - prctile(DF_sg, 50, 2);
    A(~isfinite(A) | A < 0) = 0;

    % --- Score NAÏF ---
    SNR   = A ./ noise_sigma;
    SNR(~isfinite(SNR)) = 0;

    score = max(0, SNR);
    score(~isfinite(score)) = 0;
    
    N = numel(score);
    
    % rang croissant : 1 = pire, N = meilleur
    [~, idx_sort] = sort(score, 'ascend');
    quality_rank = zeros(N,1);
    quality_rank(idx_sort) = 1:N;
    
    % (optionnel) juste pour couleur/affichage si tu veux (0..1)
    quality_index = (quality_rank - 1) / max(1, (N-1));
    
    % slider en "rang"
    quality_min  = 1;
    quality_max  = N;
    quality_thr0 = round(0.5*N);

end



%% ===================== AUTO DETECT =======================
function auto_detect_and_add(fig)
    DF_sg   = getappdata(fig,'DF_sg');
    cid     = getappdata(fig,'cell_id');
    opts    = getappdata(fig,'opts');
    noise_est = getappdata(fig,'noise_est');

    x  = DF_sg(cid,:).';
    Nx = numel(x);
    minithreshold = 0.1;

    sigma = median(noise_est(cid,:), 'omitnan');
    prominence = opts.prominence_factor * sigma;
    thr_glo = max([3 * iqr(x), 3 * std(x), minithreshold]);

    minW = max(1, round(opts.min_width_fr));
    [~, locs] = findpeaks(x, ...
        'MinPeakProminence', prominence, ...
        'MinPeakHeight',     thr_glo, ...
        'MinPeakWidth',      minW);

    if isempty(locs)
        setappdata(fig,'auto_intervals',[]);
        setappdata(fig,'auto_peaks',[]);
        setappdata(fig,'thr_glo_last',thr_glo);
        refresh_data(fig);
        return;
    end

    intervals = zeros(numel(locs), 2);
    local_win = 120;
    baseline_margin = 0.5;

    for i = 1:numel(locs)
        pk = locs(i);

        left_win  = max(1, pk - local_win);
        right_win = min(Nx, pk + local_win); %#ok<NASGU>

        local_segment = x(left_win:pk);
        baseline_local = prctile(local_segment, 10);
        noise_local = std(local_segment, 'omitnan');
        thr_event = baseline_local + baseline_margin * noise_local; % pour déterminer quand l’événement commence et se termine

        a = pk;
        while a > 1 && x(a) > thr_event
            a = a - 1;
        end

        b = pk;
        while b < Nx && x(b) > thr_event
            b = b + 1;
        end

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
            if x(pk) >= thr_glo
                locs_merged(end+1) = pk; %#ok<AGROW>
            end
        end
    end

    setappdata(fig,'auto_intervals',merged);
    setappdata(fig,'auto_peaks',locs_merged);
    setappdata(fig,'thr_glo_last',thr_glo);
    refresh_data(fig);
end


%% ===================== AFFICHAGE =======================
function refresh_data(fig)
    DF_sg   = getappdata(fig,'DF_sg');
    cell_id = getappdata(fig,'cell_id');
    
    ax = getappdata(fig,'ax1');

    % === clear léger : on garde le patch badframes s'il existe ===
    hBad = [];
    if isappdata(fig,'hBadPatch_ax1')
        hBad = getappdata(fig,'hBadPatch_ax1');
    end
    
    kids = allchild(ax);
    if ~isempty(hBad) && isgraphics(hBad)
        delete(kids(kids ~= hBad));   % supprime tout sauf le patch
    else
        delete(kids);                 % sinon on supprime tout
    end

    x = DF_sg(cell_id,:);
    x = x(:).';
    T = numel(x);
    t = 1:T;

    xlim(ax,[1 max(1,T)]);
    plot(ax,t,x,'k-'); hold(ax,'on');

    % --- mettre à jour la hauteur du bandeau (patch persistant) ---
    if ~isempty(hBad) && isgraphics(hBad) && isappdata(fig,'focus_segs')
        focus_segs = getappdata(fig,'focus_segs');
        update_badframe_patch(hBad, focus_segs, ylim(ax));
        uistack(hBad,'bottom');   % garantit que ça reste derrière
    end

    xlabel(ax,'Frames'); ylabel(ax,'\DeltaF/F (SavGol)');
   
    % Pics + intervalles
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
            plot(ax, auto_peaks, x(auto_peaks), 'r*', 'MarkerSize',8, 'LineWidth',1.2);
        end
    end

    % Ligne seuil bas
    if isappdata(fig,'thr_glo_last')
        thr_glo = getappdata(fig,'thr_glo_last');
        if isfinite(thr_glo)
            plot(ax,[1 max(1,T)],[thr_glo thr_glo],':','Color',[.7 .1 .1],'LineWidth',1);
        end
    end

    % Indicateur de qualité + statut keep/exclude
    % if isappdata(fig,'quality_index')
    %     quality_index = getappdata(fig,'quality_index');
    %     cid = getappdata(fig,'cell_id');
    %     qval = quality_index(cid);
    % 
    %     % Couleur basée sur q (0..1)
    %     if qval >= 0.75
    %         qcolor = [0.0 0.6 0.0];    % vert foncé
    %         qstyle = 'bold';
    %     elseif qval >= 0.55
    %         qcolor = [0.2 0.7 0.2];    % vert clair
    %         qstyle = 'normal';
    %     elseif qval >= 0.35
    %         qcolor = [0.9 0.6 0.1];    % orange
    %         qstyle = 'normal';
    %     else
    %         qcolor = [0.8 0.0 0.0];    % rouge
    %         qstyle = 'bold';
    %     end
    % 
    %     yMax = max(x,[],'omitnan');
    %     yMin = min(x,[],'omitnan');
    %     if ~isfinite(yMax), yMax = 1; end
    %     if ~isfinite(yMin), yMin = 0; end
    %     yPos = yMax - 0.05*(yMax - yMin);
    % 
    %     text(ax, 0.02*max(1,length(x)), yPos, sprintf('Qualité = %.2f %s', qval), ...
    %         'Color', qcolor, 'FontSize', 12, 'FontWeight', qstyle, ...
    %         'BackgroundColor',[1 1 1 0.6], 'Margin', 3);
    % end
    update_roi_zoom(fig);
end


%% ===================== SAVE PEAK MATRIX =======================
function [invalid_cells, valid_cells, DF_sg, F0, Raster, Acttmp2, StartEnd, MAct, thresholds, opts, summary] = ...
    save_peak_matrix(fig, synchronous_frames)

    DF_sg     = getappdata(fig,'DF_sg');
    opts      = getappdata(fig,'opts');
    noise_est = getappdata(fig,'noise_est');
    F0        = getappdata(fig,'F0');

    nCells = size(DF_sg,1);
    Nz     = size(DF_sg,2);

    % Quality index
    if isappdata(fig, 'quality_index')
        quality_index = getappdata(fig, 'quality_index');
    else
        quality_index = ones(nCells,1);
    end
    
    if isappdata(fig, 'quality_rank')
        quality_rank = getappdata(fig, 'quality_rank');
    else
        quality_rank = (1:nCells).'; % fallback
    end

    % Statut manuel
    if isappdata(fig,'cell_status')
        cell_status = getappdata(fig,'cell_status'); % 0 undecided, +1 keep, -1 exclude
    else
        cell_status = zeros(nCells,1);
    end

    Raster     = false(nCells, Nz);
    Acttmp2    = cell(nCells,1);
    thresholds = nan(nCells,1);
    StartEnd   = cell(nCells,1);

    minithreshold = 0.1;
    n_kept = 0;

    for cid = 1:nCells

        % 1) exclusion manuelle => skip
        if cell_status(cid) == -1
            Acttmp2{cid} = [];
            thresholds(cid) = NaN;
            Raster(cid,:) = false;
            DF_sg(cid,:) = NaN;
            continue;
        end

        % 2) keep manuel => garde même si qualité faible
        force_keep = (cell_status(cid) == +1);

        % 3) sinon, filtre qualité
        if isappdata(fig,'quality_thr')
            qthr = getappdata(fig,'quality_thr');   % valeur du slider
        end
        if ~force_keep && quality_rank(cid) < qthr % le seuil utilisé pour extraire les pics est celui du slider.
            Acttmp2{cid} = [];
            thresholds(cid) = NaN;
            Raster(cid,:) = false;
            DF_sg(cid,:) = NaN;
            fprintf('Cellule %d ignorée (rank %d < %d)\n', cid, quality_rank(cid), qthr);
            continue;
        end

        % cellule conservée
        n_kept = n_kept + 1;

        x  = DF_sg(cid,:).';
        Nx = numel(x);

        sigma = median(noise_est(cid,:), 'omitnan');
        prominence = opts.prominence_factor * sigma;
        thr_glo = max([3 * iqr(x), 3 * std(x), minithreshold]);

        minW = max(1, round(opts.min_width_fr));
        [~, locs] = findpeaks(x, ...
            'MinPeakProminence', prominence, ...
            'MinPeakHeight',     thr_glo, ...
            'MinPeakWidth',      minW);

        if isempty(locs)
            Acttmp2{cid} = [];
            thresholds(cid) = thr_glo;
            StartEnd{cid} = [];
            continue;
        end

        intervals = zeros(numel(locs), 2);
        local_win = 120;
        baseline_margin = 0.5;

        for i = 1:numel(locs)
            pk = locs(i);

            left_win  = max(1, pk - local_win);
            local_segment = x(left_win:pk);

            baseline_local = prctile(local_segment, 10);
            noise_local = std(local_segment,'omitnan');
            thr_event = baseline_local + baseline_margin * noise_local;

            a = pk;
            while a > 1 && x(a) > thr_event
                a = a - 1;
            end

            b = pk;
            while b < Nx && x(b) > thr_event
                b = b + 1;
            end

            if (b - a + 1) < minW
                d = ceil((minW - (b - a + 1))/2);
                a = max(1, a- d);
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
                if x(pk) >= thr_glo
                    locs_merged(end+1) = pk; %#ok<AGROW>
                end
            end
        end

        Acttmp2{cid} = locs_merged;
        Raster(cid, locs_merged) = true;
        thresholds(cid) = thr_glo;
        StartEnd{cid} = merged;
    end

    fprintf('\n=> %d cellules conservées sur %d (%.1f%%)\n', ...
        n_kept, nCells, 100 * n_kept / max(1,nCells));

    % activité multi-cellules
    if Nz > synchronous_frames
        MAct = zeros(1, Nz - synchronous_frames);
        for i = 1:(Nz - synchronous_frames)
            MAct(i) = sum(max(Raster(:, i:i+synchronous_frames), [], 2));
        end
    else
        MAct = zeros(1,0);
    end

    % valid/invalid
    invalid_cells = all(isnan(DF_sg), 2);
    valid_cells = find(~invalid_cells);

    % ===== summary (avec qualité moyenne) =====
    summary = struct();
    summary.n_total       = nCells;
    summary.n_manual_keep = sum(cell_status == +1);
    summary.n_manual_excl = sum(cell_status == -1);
    summary.n_undecided   = sum(cell_status == 0);
    summary.n_kept_final  = numel(valid_cells);

    % Qualité moyenne (toutes les cellules) + (finales)
    summary.mean_quality_all = mean(quality_index, 'omitnan');
    if ~isempty(valid_cells)
        summary.mean_quality_kept_final = mean(quality_index(valid_cells), 'omitnan');
    else
        summary.mean_quality_kept_final = NaN;
    end

    % Optionnel: qualité moyenne par statut manuel
    summary.mean_quality_manual_keep = mean(quality_index(cell_status == +1), 'omitnan');
    summary.mean_quality_manual_excl = mean(quality_index(cell_status == -1), 'omitnan');
    summary.mean_quality_undecided   = mean(quality_index(cell_status == 0),  'omitnan');

    % réduire aux valid_cells
    DF_sg      = DF_sg(valid_cells, :);
    F0         = F0(valid_cells, :);
    thresholds = thresholds(valid_cells, :);
    Acttmp2    = Acttmp2(valid_cells);
    StartEnd   = StartEnd(valid_cells);
    Raster     = Raster(valid_cells, :);
end

%% ===================== QUALITY THRESHOLD / TRI =======================
function update_quality_threshold(fig, thr_slider)
% update_quality_threshold
% - Mode normal : thr_slider = seuil (rank min), affiche la cellule cutoff (pire gardée)
% - Mode sélection : seuil figé (= selection_thr_locked), thr_slider = index de navigation

    % --- récup ---
    if ~isappdata(fig,'quality_rank')
        error('quality_rank non trouvé dans appdata.');
    end
    quality_rank = getappdata(fig,'quality_rank');   % 1..N (1=pire, N=meilleur)
    N = numel(quality_rank);

    if isappdata(fig,'cell_status')
        cell_status = getappdata(fig,'cell_status'); % -1 exclu, +1 keep, 0 neutre
    else
        cell_status = zeros(N,1);
    end

    % --- selection_mode robuste ---
    selection_mode = isappdata(fig,'selection_mode') && logical(getappdata(fig,'selection_mode'));

    % slider entier
    thr_slider = round(thr_slider);

    % ============================================================
    % MODE SÉLECTION : seuil FIXE (lock), slider = NAVIGATION (index)
    % ============================================================
    if selection_mode && isappdata(fig,'selection_thr_locked')
    
        order_cells = getappdata(fig,'order_cells');
        if isempty(order_cells), return; end
    
        idx = max(1, min(numel(order_cells), round(thr_slider)));
        new_cid = order_cells(idx);
    
        setappdata(fig,'cell_index_in_order', idx);
        setappdata(fig,'cell_id', new_cid);
    
        lbl = findobj(fig,'Tag','lbl_quality_thr');
        if ~isempty(lbl)
            lbl.String = sprintf('MODE SÉLECTION — navigation (%d / %d)', idx, numel(order_cells));
        end
    
        setappdata(fig,'auto_intervals', []);
        if isappdata(fig,'thr_glo_last'), rmappdata(fig,'thr_glo_last'); end
        auto_detect_and_add(fig);
        refresh_data(fig);
        update_peak_histogram(fig);
        return;
    end

    % ============================================================
    % MODE NORMAL : slider = SEUIL (rank min), affiche la cutoff
    % ============================================================

    % clamp seuil
    thr_eff = max(1, min(N, thr_slider));

    % si pas en sélection -> supprimer lock résiduel
    if ~selection_mode && isappdata(fig,'selection_thr_locked')
        rmappdata(fig,'selection_thr_locked');
    end

    % cellules éligibles (rank >= seuil)
    valid_cells = find((quality_rank >= thr_eff) & (cell_status ~= -1));

    % label
    lbl = findobj(fig,'Tag','lbl_quality_thr');
    if ~isempty(lbl)
        lbl.String = sprintf('Rang minimum = %d', thr_eff);
    end

    ax = getappdata(fig,'ax1');

    if isempty(valid_cells)
        setappdata(fig,'order_cells', []);
        setappdata(fig,'cell_index_in_order', []);
        if ~isempty(ax) && ishghandle(ax)
            cla(ax);
            title(ax, sprintf('Aucune cellule avec rang >= %d', thr_eff));
        end
        drawnow;
        return;
    end

    % ordre : meilleur -> pire
    [~, ord] = sort(quality_rank(valid_cells), 'descend');
    order_cells = valid_cells(ord);
    setappdata(fig,'order_cells', order_cells);

    % en mode normal : afficher la cellule cutoff = pire parmi gardées = FIN de liste
    idx = numel(order_cells);
    new_cid = order_cells(idx);

    setappdata(fig,'cell_index_in_order', idx);
    setappdata(fig,'cell_id', new_cid);

    % stocker seuil
    setappdata(fig,'quality_thr', thr_eff);

    % reset détection auto
    setappdata(fig,'auto_intervals', []);
    if isappdata(fig,'thr_glo_last'), rmappdata(fig,'thr_glo_last'); end

    auto_detect_and_add(fig);
    refresh_data(fig);
    update_peak_histogram(fig);
end

%% ===================== NAVIGATION =======================
function next_cell(fig)

    % --- seuil courant (ENTIER + clamp) ---
    if isappdata(fig,'quality_rank')
        N = numel(getappdata(fig,'quality_rank'));
    else
        return;
    end

    sldr = findobj(fig,'Tag','sldr_quality_thr');
    if ~isempty(sldr) && isgraphics(sldr)
        thr = round(get(sldr,'Value'));
    elseif isappdata(fig,'quality_thr')
        thr = round(getappdata(fig,'quality_thr'));
    else
        thr = 1;
    end
    thr = max(1, min(N, thr));

    % --- ordre ---
    order_cells = compute_order_cells(fig, thr);
    setappdata(fig,'order_cells', order_cells);
    if isempty(order_cells)
        return;
    end

    % --- cellule courante ---
    cid = [];
    if isappdata(fig,'cell_id'), cid = getappdata(fig,'cell_id'); end
    if ~(isnumeric(cid) && isscalar(cid) && isfinite(cid))
        cid = order_cells(1);
    else
        cid = round(cid);
    end

    % --- position ---
    idx = find(order_cells == cid, 1);
    if isempty(idx)
        idx = numel(order_cells);  % repartir de la cutoff (pire gardée)
    end

    % --- avancer ---
    idx = min(idx + 1, numel(order_cells));
    new_cid = order_cells(idx);

    % --- set ---
    setappdata(fig,'cell_index_in_order', idx);
    setappdata(fig,'cell_id', new_cid);

    % reset détection auto
    setappdata(fig,'auto_intervals', []);
    if isappdata(fig,'thr_event_last'), rmappdata(fig,'thr_event_last'); end
    if isappdata(fig,'thr_glo_last'),   rmappdata(fig,'thr_glo_last'); end

    auto_detect_and_add(fig);
    refresh_data(fig);
    update_peak_histogram(fig);
end

function prev_cell(fig)

    % --- seuil courant (ENTIER + clamp) ---
    if isappdata(fig,'quality_rank')
        N = numel(getappdata(fig,'quality_rank'));
    else
        return;
    end

    sldr = findobj(fig,'Tag','sldr_quality_thr');
    if ~isempty(sldr) && isgraphics(sldr)
        thr = round(get(sldr,'Value'));
    elseif isappdata(fig,'quality_thr')
        thr = round(getappdata(fig,'quality_thr'));
    else
        thr = 1;
    end
    thr = max(1, min(N, thr));

    % --- ordre ---
    order_cells = compute_order_cells(fig, thr);
    setappdata(fig,'order_cells', order_cells);
    if isempty(order_cells)
        return;
    end

    % --- cellule courante ---
    cid = [];
    if isappdata(fig,'cell_id'), cid = getappdata(fig,'cell_id'); end
    if ~(isnumeric(cid) && isscalar(cid) && isfinite(cid))
        cid = order_cells(1);
    else
        cid = round(cid);
    end

    % --- position ---
    idx = find(order_cells == cid, 1);
    if isempty(idx)
        idx = 1;
    end

    % --- reculer ---
    idx = max(idx - 1, 1);
    new_cid = order_cells(idx);

    % --- set ---
    setappdata(fig,'cell_index_in_order', idx);
    setappdata(fig,'cell_id', new_cid);

    % reset détection auto
    setappdata(fig,'auto_intervals', []);
    if isappdata(fig,'thr_event_last'), rmappdata(fig,'thr_event_last'); end
    if isappdata(fig,'thr_glo_last'),   rmappdata(fig,'thr_glo_last'); end

    auto_detect_and_add(fig);
    refresh_data(fig);
    update_peak_histogram(fig);
end


function navigate_cells(fig, evnt)
    switch evnt.Key
        case 'rightarrow', next_cell(fig);
        case 'leftarrow',  prev_cell(fig);
    end
end


%% ===================== KEEP / EXCLUDE / FINALIZE =======================
function keep_cell(fig)
    cid = getappdata(fig,'cell_id');
    st  = getappdata(fig,'cell_status');
    st(cid) = +1;
    setappdata(fig,'cell_status', st);

    if isappdata(fig,'selection_mode') && logical(getappdata(fig,'selection_mode'))
        refresh_selection_order(fig);
    else
        next_cell(fig);
    end
end

function exclude_cell(fig)
    cid = getappdata(fig,'cell_id');
    st  = getappdata(fig,'cell_status');
    st(cid) = -1;
    setappdata(fig,'cell_status', st);

    % Update live si mode sélection, sinon navigation normale
    if isappdata(fig,'selection_mode') && logical(getappdata(fig,'selection_mode'))
        refresh_selection_order(fig);
    else
        next_cell(fig);
    end
end


function finalize_and_close(fig, synchronous_frames)
    [invalid_cells, valid_cells, DF_sg, F0, Raster, Acttmp2, StartEnd, MAct, thresholds, opts, summary] = ...
        save_peak_matrix(fig, synchronous_frames);
    
    % === RASTER + FOCUS SEGS ===
    if isappdata(fig,'focus_segs')
        focus_segs = getappdata(fig,'focus_segs');
    else
        focus_segs = [];
    end

    plot_raster_window(Raster, focus_segs);

    % mapping : index original -> index dans matrices compactées
    orig2new = nan(max(valid_cells),1);
    orig2new(valid_cells) = 1:numel(valid_cells);

    if iscell(Acttmp2) && size(Acttmp2,2) > 1, Acttmp2 = reshape(Acttmp2, [], 1); end
    if iscell(StartEnd) && size(StartEnd,2) > 1, StartEnd = reshape(StartEnd, [], 1); end

    setappdata(fig,'last_save_outputs', struct( ...
        'invalid_cells', invalid_cells, ...
        'valid_cells', valid_cells, ...
        'orig2new', orig2new, ...          % <--- AJOUT
        'DF_sg', DF_sg, 'F0', F0, ...
        'Raster', Raster, 'Acttmp2', {Acttmp2}, 'StartEnd', {StartEnd}, ...
        'MAct', MAct, 'thresholds', thresholds, 'opts', opts, 'summary', summary));

    if ishghandle(fig)
        uiresume(fig);
        close(fig);
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
            if mod(value,2)==0, value = value+1; end
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
        base = lbl.String(1:strfind(lbl.String,'=')-2);
        if ismember(field,intFields)
            lbl.String = sprintf('%s = %d', base, value);
        else
            lbl.String = sprintf('%s = %.2f', base, value);
        end
    end

    % Si savgol_win change: recalcul DF_sg, noise, SNR + MAJ slider qualité
    if strcmp(field,'savgol_win')
        F_raw = getappdata(fig,'F_raw');
        [DF, DF_sg, F0, noise_est, SNR, quality_index, quality_rank, quality_min, quality_max, quality_thr0] = DF_processing(F_raw, opts);

        setappdata(fig,'DF', DF);
        setappdata(fig,'DF_sg', DF_sg);
        setappdata(fig,'F0', F0);
        setappdata(fig,'noise_est', noise_est);
        setappdata(fig,'SNR', SNR);
        setappdata(fig,'quality_index', quality_index);   % pour couleur/affichage
        setappdata(fig,'quality_rank',  quality_rank);    % pour tri + seuil

        sldr = findobj(fig,'Tag','sldr_quality_thr');
        if ~isempty(sldr)
            sldr.Min   = quality_min;
            sldr.Max   = quality_max;
            sldr.Value = quality_thr0;
        end
        sLbl = findobj(fig,'Tag','lbl_quality_thr');
        if ~isempty(sLbl)
            sLbl.String = sprintf('Quality threshold = %.2f', quality_thr0);
        end

        % IMPORTANT: si on change le lissage, on garde le cell_status tel quel
        % mais on recalcule l'ordre/affichage sur le nouveau quality_thr0
        update_quality_threshold(fig, quality_thr0);
        recompute_n_peaks_all(fig);
        update_peak_histogram(fig);
        return;
    end

    auto_detect_and_add(fig);
    recompute_n_peaks_all(fig);
    update_peak_histogram(fig);
    refresh_data(fig);
end

function recompute_n_peaks_all(fig)
    DF_sg     = getappdata(fig,'DF_sg');
    noise_est = getappdata(fig,'noise_est');
    opts      = getappdata(fig,'opts');

    nCells = size(DF_sg,1);
    n_peaks_all = zeros(nCells,1);

    for cid = 1:nCells
        x = DF_sg(cid,:).';
        sigma = median(noise_est(cid,:), 'omitnan');
        if ~isfinite(sigma) || sigma<=0
            sigma = std(x,'omitnan');
        end

        locs_merged = detect_peaks_cell_v1(x, sigma, opts);
        n_peaks_all(cid) = numel(locs_merged);
    end

    setappdata(fig,'n_peaks_all', n_peaks_all);
end


function locs_merged = detect_peaks_cell_v1(x, sigma, opts)
    Nx = numel(x);
    minithreshold = 0.1;

    prominence = opts.prominence_factor * max(sigma, eps);
    thr_glo = max([3 * iqr(x), 3 * std(x), minithreshold]);

    minW = max(1, round(opts.min_width_fr));
    [~, locs] = findpeaks(x, ...
        'MinPeakProminence', prominence, ...
        'MinPeakHeight',     thr_glo, ...
        'MinPeakWidth',      minW);

    if isempty(locs)
        locs_merged = [];
        return;
    end

    % Intervalles autour de chaque pic (même logique que ton code)
    intervals = zeros(numel(locs), 2);
    local_win = 120;
    baseline_margin = 0.5;

    for i = 1:numel(locs)
        pk = locs(i);

        left_win  = max(1, pk - local_win);
        local_segment = x(left_win:pk);

        baseline_local = prctile(local_segment, 10);
        noise_local = std(local_segment,'omitnan');
        thr_event = baseline_local + baseline_margin * noise_local;

        a = pk; while a > 1  && x(a) > thr_event, a = a - 1; end
        b = pk; while b < Nx && x(b) > thr_event, b = b + 1; end

        if (b - a + 1) < minW
            d = ceil((minW - (b - a + 1))/2);
            a = max(1, a - d);
            b = min(Nx, b + d);
        end

        intervals(i,:) = [a b];
    end

    % Fusion réfractaire (refrac_fr)
    intervals = sortrows(intervals,1);
    merged = [];
    cur = intervals(1,:);
    gap = max(0, round(opts.refrac_fr));

    for i=2:size(intervals,1)
        if intervals(i,1) <= cur(2) + gap
            cur(2) = max(cur(2), intervals(i,2));
        else
            merged = [merged; cur]; %#ok<AGROW>
            cur = intervals(i,:);
        end
    end
    merged = [merged; cur];

    % Un seul pic par intervalle fusionné (max amplitude)
    locs_merged = [];
    for r=1:size(merged,1)
        in_interval = locs(locs >= merged(r,1) & locs <= merged(r,2));
        if ~isempty(in_interval)
            [~, idx] = max(x(in_interval));
            locs_merged(end+1) = in_interval(idx); %#ok<AGROW>
        end
    end
end


function update_peak_histogram(fig)
    axH = getappdata(fig,'axH');
    if isempty(axH) || ~ishghandle(axH), return; end

    if ~isappdata(fig,'n_peaks_all')
        cla(axH); title(axH,'# pics / cellule'); return;
    end

    n_peaks_all = getappdata(fig,'n_peaks_all');
    if isempty(n_peaks_all)
        cla(axH); title(axH,'# pics / cellule'); return;
    end

    % --- cellule courante (pour ligne verticale) ---
    xcur = NaN;
    cid = NaN;
    if isappdata(fig,'cell_id')
        cid = getappdata(fig,'cell_id');
        if ~isempty(cid) && isscalar(cid) && cid>=1 && cid<=numel(n_peaks_all)
            xcur = n_peaks_all(cid);
        end
    end

    % --- histogramme ---
    cla(axH); hold(axH,'on');
    histogram(axH, n_peaks_all, 'BinMethod','integers');

    % --- ligne verticale pointillée ---
    if isfinite(xcur)
        xline(axH, xcur, 'k--', 'LineWidth', 1.5);
        title(axH, sprintf('Cellule %d : %d pics', cid, xcur));
    else
        title(axH,'# pics / cellule');
    end

    xlabel(axH,'Nombre de pics'); ylabel(axH,'Nombre de cellules');
    box(axH,'on');
end

function enter_selection_mode(fig)

    setappdata(fig,'selection_mode', true);

    sldr = findobj(fig,'Tag','sldr_quality_thr');
    thr_lock = round(get(sldr,'Value'));
    setappdata(fig,'selection_thr_locked', thr_lock);

    % ordre "normal" (meilleur -> pire)
    order_cells = compute_order_cells(fig, thr_lock);
    if isempty(order_cells)
        return;
    end

    % >>> INVERSION pour que 1 = cutoff (pire) et fin = meilleur
    order_cells = flipud(order_cells(:));

    setappdata(fig,'order_cells', order_cells);

    % slider devient un slider d'INDEX et démarre au début (= cutoff)
    n = numel(order_cells);
    set(sldr,'Min',1,'Max',n,'Value',1);
    step = 1/max(1,n-1);
    set(sldr,'SliderStep',[step min(1,10*step)]);

    % afficher la 1ère cellule (cutoff)
    setappdata(fig,'cell_index_in_order', 1);
    setappdata(fig,'cell_id', order_cells(1));

    update_quality_threshold(fig, 1);
end


function order_cells = compute_order_cells(fig, thr_slider)

    % --- récup depuis appdata ---
    if isappdata(fig,'quality_rank')
        quality_rank = getappdata(fig,'quality_rank');   % 1..N (1=pire, N=meilleur)
    else
        order_cells = [];
        return;
    end

    if isappdata(fig,'cell_status')
        cell_status = getappdata(fig,'cell_status');     % -1 exclu, +1 keep, 0 neutre
    else
        cell_status = zeros(numel(quality_rank),1);
    end

    % --- selection_mode ? ---
    selection_mode = isappdata(fig,'selection_mode') && logical(getappdata(fig,'selection_mode'));

    % --- seuil effectif (lock seulement si sélection) ---
    thr_slider = round(thr_slider);
    thr_eff = thr_slider;

    if selection_mode && isappdata(fig,'selection_thr_locked')
        thr_lock = round(getappdata(fig,'selection_thr_locked'));
        thr_eff = max(thr_slider, thr_lock);   % lock : empêche de descendre sous le lock
    end

    % --- cellules éligibles : rank >= thr_eff (meilleures) ---
    valid_cells = find((quality_rank >= thr_eff) & (cell_status ~= -1));

    if selection_mode
        valid_cells = union(valid_cells, find(cell_status == +1));  % keep toujours
        valid_cells = setdiff(valid_cells, find(cell_status == -1));% exclu jamais
    end

    if isempty(valid_cells)
        order_cells = [];
        return;
    end

    % --- ordre : meilleur -> pire ---
    [~, ord] = sort(quality_rank(valid_cells), 'descend');
    order_cells = valid_cells(ord);
end



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
    for k=1:numel(cuts)-1
        a = idx(cuts(k));
        b = idx(cuts(k+1)-1);
        segs(k,:) = [a b];
    end
end

function h = create_badframe_patch(ax, segs)
    if isempty(segs) || isempty(ax) || ~ishghandle(ax)
        h = gobjects(1);
        return;
    end

    % patch multi-rectangles (X/Y contiennent des NaN entre rectangles)
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

    for k=1:n
        a = segs(k,1);
        b = segs(k,2);

        ii = (k-1)*5 + (1:5);
        X(ii) = [a b b a a];
        Y(ii) = [y0 y0 y1 y1 y0];
    end
end

function refresh_selection_order(fig)
    % Ne fait quelque chose que si on est en mode sélection
    if ~(isappdata(fig,'selection_mode') && logical(getappdata(fig,'selection_mode')))
        return;
    end
    if ~isappdata(fig,'selection_thr_locked')
        return;
    end

    thr_lock = round(getappdata(fig,'selection_thr_locked'));

    % Recalcule order_cells (même logique que compute_order_cells + inversion si tu l’utilises)
    order_cells = compute_order_cells(fig, thr_lock);   % renvoie meilleur -> pire
    if isempty(order_cells)
        % plus rien à naviguer
        setappdata(fig,'order_cells', []);
        sldr = findobj(fig,'Tag','sldr_quality_thr');
        if ~isempty(sldr) && isgraphics(sldr)
            set(sldr,'Min',1,'Max',1,'Value',1,'SliderStep',[1 1]);
        end
        lbl = findobj(fig,'Tag','lbl_quality_thr');
        if ~isempty(lbl)
            lbl.String = sprintf('MODE SÉLECTION — navigation (0 / 0)');
        end
        return;
    end

    % >>> si en sélection tu avais inversé l’ordre (cutoff -> meilleurs)
    order_cells = flipud(order_cells(:));              % cutoff d'abord

    old_order = [];
    if isappdata(fig,'order_cells'), old_order = getappdata(fig,'order_cells'); end
    old_idx = 1;
    if isappdata(fig,'cell_index_in_order'), old_idx = round(getappdata(fig,'cell_index_in_order')); end
    old_idx = max(1, old_idx);

    % cellule courante si possible
    cid = [];
    if isappdata(fig,'cell_id'), cid = getappdata(fig,'cell_id'); end

    % Choisir nouvel index :
    % 1) si cid encore présent => rester dessus
    % 2) sinon => garder old_idx clampé sur la nouvelle taille
    if ~isempty(cid)
        idx = find(order_cells == cid, 1);
    else
        idx = [];
    end
    if isempty(idx)
        idx = min(old_idx, numel(order_cells));
    end

    % Stock
    setappdata(fig,'order_cells', order_cells);
    setappdata(fig,'cell_index_in_order', idx);
    setappdata(fig,'cell_id', order_cells(idx));

    % Update slider (index)
    sldr = findobj(fig,'Tag','sldr_quality_thr');
    if ~isempty(sldr) && isgraphics(sldr)
        n = numel(order_cells);
        set(sldr,'Min',1,'Max',n,'Value',idx);
        step = 1/max(1,n-1);
        set(sldr,'SliderStep',[step min(1,10*step)]);
    end

    % Label
    lbl = findobj(fig,'Tag','lbl_quality_thr');
    if ~isempty(lbl)
        lbl.String = sprintf('MODE SÉLECTION — navigation (%d / %d)', idx, numel(order_cells));
    end

    % Refresh affichage
    setappdata(fig,'auto_intervals', []);
    if isappdata(fig,'thr_glo_last'), rmappdata(fig,'thr_glo_last'); end
    auto_detect_and_add(fig);
    refresh_data(fig);
    update_peak_histogram(fig);
end

function update_roi_zoom(fig)
% update_roi_zoom
% Affiche la meanImg zoomée autour de la cellule courante (cid) avec
% contraste local (basé sur le crop) + contour Suite2p via xext/yext.
%
% Pré-requis appdata:
%   'axROI'   : axes
%   'meanImg' : image moyenne (H x W) numérique
%   'stat'    : stat (cell/struct/py.list)
%   'cell_id' : index cellule (1-based)

    if ~isappdata(fig,'axROI'), return; end
    ax = getappdata(fig,'axROI');
    if isempty(ax) || ~ishghandle(ax), return; end

    % --- meanImg ---
    meanImg = [];
    if isappdata(fig,'meanImg')
        meanImg = getappdata(fig,'meanImg');
    end
    if isempty(meanImg) || ~(isnumeric(meanImg) || islogical(meanImg))
        cla(ax);
        title(ax,'ROI (zoom)');
        text(ax,0.5,0.5,'meanImg non disponible/numérique', ...
            'Units','normalized','HorizontalAlignment','center');
        return;
    end
    meanImg = double(meanImg);

    % --- cid ---
    if ~isappdata(fig,'cell_id')
        cla(ax); imagesc(ax, meanImg); colormap(ax,gray); axis(ax,'image');
        set(ax,'YDir','reverse'); title(ax,'ROI (zoom)');
        return;
    end
    cid = round(getappdata(fig,'cell_id'));

    % --- stat ---
    if ~isappdata(fig,'stat')
        cla(ax);
        imagesc(ax, meanImg); colormap(ax,gray); axis(ax,'image'); set(ax,'YDir','reverse');
        title(ax, sprintf('Cell %d — stat absent', cid));
        return;
    end
    stat_in = getappdata(fig,'stat');

    % ============================================================
    % 1) Extraire contour xext/yext (0-based -> 1-based)
    % ============================================================
    [xext, yext] = get_xext_yext(stat_in, cid);

    cla(ax); hold(ax,'on');

    if isempty(xext) || isempty(yext) || numel(xext) < 3
        % fallback: juste afficher meanImg entier si pas de contour
        imagesc(ax, meanImg); colormap(ax,gray); axis(ax,'image');
        set(ax,'YDir','reverse');
        title(ax, sprintf('Cellule %d — xext/yext vide', cid));
        hold(ax,'off');
        return;
    end

    % fermer le contour
    xext = xext(:); yext = yext(:);
    if xext(1) ~= xext(end) || yext(1) ~= yext(end)
        xext(end+1) = xext(1);
        yext(end+1) = yext(1);
    end

    % ============================================================
    % 2) Définir bbox + crop (zoom)
    % ============================================================
    pad = 12;

    xmin = floor(min(xext)) - pad;
    xmax = ceil(max(xext)) + pad;
    ymin = floor(min(yext)) - pad;
    ymax = ceil(max(yext)) + pad;

    [H,W] = size(meanImg);
    xmin = max(1, xmin); xmax = min(W, xmax);
    ymin = max(1, ymin); ymax = min(H, ymax);

    cropImg = meanImg(ymin:ymax, xmin:xmax);

    % ============================================================
    % 3) Contraste local (sur crop uniquement)
    % ============================================================
    v = cropImg(isfinite(cropImg));
    if isempty(v)
        lo = min(cropImg(:)); hi = max(cropImg(:));
    else
        lo = prctile(v, 5);
        hi = prctile(v, 99.5);
        if ~isfinite(lo) || ~isfinite(hi) || hi <= lo
            lo = min(v); hi = max(v);
        end
    end

    % afficher le crop avec CLim local
    imagesc(ax, cropImg);
    colormap(ax, gray);
    axis(ax, 'image');
    set(ax,'YDir','reverse');
    clim(ax, [lo hi]);

    % ============================================================
    % 4) Recaler contour en coordonnées du crop et tracer
    % ============================================================
    % 1) Construire masque pixel-wise
    H = ymax - ymin + 1;
    W = xmax - xmin + 1;
    mask = false(H, W);
    
    % coordonnées locales
    xloc = round(xext - (xmin - 1));
    yloc = round(yext - (ymin - 1));
    
    valid = xloc>=1 & xloc<=W & yloc>=1 & yloc<=H;
    idx = sub2ind([H W], yloc(valid), xloc(valid));
    mask(idx) = true;
    
    % 2) Nettoyage léger
    mask = imclose(mask, strel('disk',1));
    mask = bwareaopen(mask, 10);   % enlève pixels dégénérés
    
    % 3) Extraire contour
    B = bwboundaries(mask, 'noholes');
    
    if ~isempty(B)
        boundary = B{1};
        yb = boundary(:,1);
        xb = boundary(:,2);
    
        % 4) Tracé propre
        plot(ax, xb, yb, 'k-', 'LineWidth', 4);
        plot(ax, xb, yb, 'r-', 'LineWidth', 2.5);
    end

    title(ax, sprintf('Cellule %d — ROI zoom (contraste local)', cid));
    hold(ax,'off');
end


function [x, y] = get_xext_yext(stat_in, cid)
% Retourne xext,yext en 1-based MATLAB, vide si introuvable.

    x = []; y = [];
    if ~(isnumeric(cid) && isscalar(cid) && isfinite(cid) && cid>=1)
        return;
    end

    try
        if isa(stat_in,'py.list')
            if cid > int64(length(stat_in)), return; end
            s = stat_in{py.int(cid-1)};

            % xext/yext
            if isKey(s, 'xext') && isKey(s, 'yext')
                x = double(s{'xext'}) + 1;
                y = double(s{'yext'}) + 1;
            else
                return;
            end

        elseif iscell(stat_in)
            if cid > numel(stat_in), return; end
            s = stat_in{cid};
            if isfield(s,'xext') && isfield(s,'yext')
                x = double(s.xext) + 1;
                y = double(s.yext) + 1;
            else
                return;
            end

        else % struct array
            if cid > numel(stat_in), return; end
            s = stat_in(cid);
            if isfield(s,'xext') && isfield(s,'yext')
                x = double(s.xext) + 1;
                y = double(s.yext) + 1;
            else
                return;
            end
        end

        % sécurité
        x = x(:); y = y(:);
        good = isfinite(x) & isfinite(y);
        x = x(good); y = y(good);

    catch
        x = []; y = [];
    end
end

function [user_segs, user_frames] = enter_observed_deviations(tifPath, T)
% enter_observed_deviations
% Indique à l'utilisateur quel TIFF ouvrir dans Fiji (manuellement),
% puis récupère une saisie de FRAMES uniquement (ex: 120:140).
%
% Inputs:
%   tifPath : chemin complet vers le .tif (ex: cam_crop.tif)
%   T       : nombre total de frames (optionnel)
%
% Outputs:
%   user_segs   : Nx2 segments [start end]
%   user_frames : frames uniques triées

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

    % --- Aucun ---
    if isempty(x)
        fprintf('Aucune déviation saisie.\n');
        user_segs = zeros(0,2);
        user_frames = [];
        return;
    end

    % --- Validation stricte ---
    if ~isnumeric(x) || ~isvector(x)
        error('Entrée invalide: entrer UNIQUEMENT un vecteur de frames.');
    end

    % Nettoyage
    fr = round(x(:).');
    fr = fr(isfinite(fr));

    if ~isempty(T)
        fr = fr(fr>=1 & fr<=T);
    else
        fr = fr(fr>=1);
    end

    fr = unique(fr);

    % Conversion frames -> segments
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
% sort_segments_by_deviation
% Trie des segments [start end] selon la déviation dans le segment.
% Hypothèse: les grandes déviations sont les plus NEGATIVES.
%
% Inputs:
%   bad_segs   : Nx2 (start,end) en frames (1-indexed)
%   deviation  : vecteur 1xT ou Tx1
%
% Output:
%   segTable : table triée avec StartFrame, EndFrame, FrameExtent, ValMaxDeviation

    if nargin < 2
        error('Usage: segTable = sort_segments_by_deviation(bad_segs, deviation)');
    end

    deviation = deviation(:).';   % row
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
    valMax = nan(N,1);  % ici = minimum (plus négatif) dans le segment

    for k = 1:N
        a = round(bad_segs(k,1));
        b = round(bad_segs(k,2));

        % normaliser
        if a > b
            tmp = a; a = b; b = tmp;
        end

        % clip dans [1..T]
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
            valMax(k) = min(segVals);   % plus négatif = “plus grande” déviation
        end
    end

    segTable = table(startF, endF, extent, valMax, ...
        'VariableNames', {'StartFrame','EndFrame','FrameExtent','ValMaxDeviation'});

    % Trier: ordre croissant (plus négatif d'abord)
    segTable = sortrows(segTable, 'ValMaxDeviation', 'ascend');
end

function plot_raster_window(Raster, focus_segs)
% plot_raster_window
% Raster : logical [nCells x T]
% focus_segs : Nx2 [start end] frames (optionnel)

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
    hold(ax,'on'); box(ax,'on');

    % ================= RASTER =================
    [cells, frames] = find(Raster);
    scatter(ax, frames, cells, 8, 'k', 'filled');

    xlim(ax,[1 T]);
    ylim(ax,[0.5 nC+0.5]);
    xlabel(ax,'Frames');
    ylabel(ax,'Cellules (valid\_cells)');
    title(ax, sprintf('Raster (%d cellules)', nC));

    % ================= FOCUS SEGS =================
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