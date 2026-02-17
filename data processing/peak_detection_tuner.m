function [DF, F0, noise_est, SNR, valid_cells, DF_sg, Raster, Acttmp2, StartEnd, MAct, thresholds] = ...
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
        'prominence_factor', 4.62, ...
        'refrac_fr', 3 ...
    );

    % Vérifie si mode batch/no-GUI
    nogui = false;
    fall_path = '';
    corrXY = [];
    
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
    
            key = lower(char(key));
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
    
            end
        end
    end


    % --- Prétraitement ---
    [DF, DF_sg, F0, noise_est, SNR, quality_index, quality_min, quality_max, quality_thr0] = DF_processing(F, opts, fs);
    
    speed = [];
    [deviation, bad_frames] = motion_correction_substraction (DF_sg,ops,speed);
    deviation = deviation(:).';  % force row
    
    % === MODE BATCH (pas de GUI) ===
    if nogui
        fig = figure('Visible','off'); % fig cachée pour utiliser appdata
        setappdata(fig,'DF_sg',DF_sg);
        setappdata(fig,'opts',opts);
        setappdata(fig,'noise_est',noise_est);
        setappdata(fig,'F0',F0);
        setappdata(fig,'quality_index', quality_index);
        setappdata(fig,'deviation',deviation);
        setappdata(fig,'bad_frames',bad_frames);

        % cell_status: 0 undecided, +1 keep, -1 exclude
        setappdata(fig,'cell_status', zeros(size(DF_sg,1),1));

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
    uicontrol('Parent',ctrl_panel,'Style','text','String',sprintf('Quality threshold = %.2f',quality_thr0), ...
        'Units','normalized','Position',[0.05 0.92 0.90 0.04], 'Tag','lbl_quality_thr', ...
        'HorizontalAlignment','left');

    uicontrol('Parent',ctrl_panel,'Style','slider','Min',quality_min,'Max',quality_max, ...
        'Value',quality_thr0,'Units','normalized','Position',[0.05 0.87 0.90 0.04], ...
        'Tag','sldr_quality_thr', ...
        'Callback',@(src,~) update_quality_threshold(fig,get(src,'Value')));

    % --- Navigation ---
    uicontrol('Parent',ctrl_panel,'Style','pushbutton','String','Cellule suivante', ...
        'Units','normalized','Position',[0.05 0.14 0.90 0.06], ...
        'Callback',@(src,~) next_cell(fig));
    uicontrol('Parent',ctrl_panel,'Style','pushbutton','String','Cellule précédente', ...
        'Units','normalized','Position',[0.05 0.20 0.90 0.06], ...
        'Callback', @(src,~) prev_cell(fig));

    % --- Garder / Exclure cellule ---
    uicontrol('Parent',ctrl_panel,'Style','pushbutton','String','Garder cellule', ...
        'Units','normalized','Position',[0.05 0.36 0.90 0.06], ...
        'BackgroundColor',[0.25 0.65 0.25], 'ForegroundColor','w', 'FontWeight','bold', ...
        'Callback', @(src,~) keep_cell(fig));

    uicontrol('Parent',ctrl_panel,'Style','pushbutton','String','Exclure cellule', ...
        'Units','normalized','Position',[0.05 0.28 0.90 0.06], ...
        'BackgroundColor',[0.85 0.3 0.3], 'ForegroundColor','w', 'FontWeight','bold', ...
        'Callback', @(src,~) exclude_cell(fig));

    % --- Terminer : calcule pics sur sélection finale + ferme ---
    uicontrol('Parent',ctrl_panel,'Style','pushbutton','String','Extraire les pics', ...
    'Units','normalized','Position',[0.05 0.06 0.90 0.06], ...
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
    
    % ---- Axe déviation (bas, aligné X) ----
    axDev = axes('Parent',fig,'Position',[0.28 0.52 0.70 0.07]);
    box(axDev,'on'); ylabel(axDev,'Dev');
    plot(axDev,NaN,NaN,'k-'); hold(axDev,'on');
    set(axDev,'XTickLabel',[]); % optionnel: éviter doublon de labels
    
    setappdata(fig,'ax1',ax1);
    setappdata(fig,'axDev',axDev);
    
    % Lier les axes en X (navigation / zoom cohérents)
    linkaxes([ax1 axDev],'x');

    % ---- Axe histogramme (bas droite) ----
    axH = axes('Parent',fig,'Position',[0.62 0.08 0.35 0.32]);
    box(axH,'on');
    title(axH,'# pics / cellule');
    xlabel(axH,'Nombre de pics');
    ylabel(axH,'Nombre de cellules');

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
    setappdata(fig,'quality_index', quality_index);
    setappdata(fig,'quality_min', quality_min);
    setappdata(fig,'quality_max', quality_max);
    setappdata(fig,'quality_thr', quality_thr0);
    setappdata(fig,'axH',axH);
    setappdata(fig,'deviation',deviation);
    setappdata(fig,'bad_frames',bad_frames);

    % cell_status: 0 undecided, +1 keep, -1 exclude
    nCells = size(F,1);
    setappdata(fig,'cell_status', zeros(nCells,1));

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
function [DF, DF_sg, F0, noise_est, SNR, quality_index, quality_min, quality_max, quality_thr0] = ...
    DF_processing(F, opts, fs)

    % --------- Params ---------
    sg_win  = opts.savgol_win;
    sg_poly = opts.savgol_poly;

    if nargin < 3 || isempty(fs) || ~isfinite(fs) || fs <= 0
        fs = 20;
    end

    % Fenêtre bruit (~0.25 s)
    noise_window = round(0.25 * fs);
    noise_window = max(11, min(41, noise_window));
    if mod(noise_window,2)==0, noise_window = noise_window + 1; end

    snr_min_cap = 1e-3;

    % --- Step 1: baseline + dF/F ---
    [F0, DF] = baseline_calculation(F);

    [NCell, Nz] = size(DF);

    noise_window = min(noise_window, Nz);
    if mod(noise_window,2)==0, noise_window = max(1, noise_window-1); end

    DF_sg     = nan(NCell, Nz);
    noise_est = nan(NCell, Nz);

    % Fenêtre SavGol
    sgN = max(sg_poly+2, round(sg_win));
    if mod(sgN,2)==0, sgN = sgN+1; end
    sgN = min(sgN, Nz - (mod(Nz,2)==0));     % <= Nz et impair
    if sgN <= sg_poly
        sgN = sg_poly + 1 + mod(sg_poly+1,2);
        sgN = min(sgN, Nz - (mod(Nz,2)==0));
    end

    for n = 1:NCell
        sig = DF(n,:);

        % SavGol (lent + pics, lissé)
        sig_sg = sig;
        if all(isfinite(sig)) && sgN >= (sg_poly+2) && sgN <= Nz
            try
                sig_sg = sgolayfilt(sig, sg_poly, sgN);
            catch
                sig_sg = sig;
            end
        end
        DF_sg(n,:) = sig_sg;

        % ============================================================
        % TEST "pas bon" : bruit = MAD locale sur le signal LISSÉ
        % (donc ça mélange encore bruit rapide + variations lentes)
        % movmad(...,1) = MAD (non-scalée) -> on met 1.4826 pour sigma
        % ============================================================
        mad_loc = movmad(sig_sg, noise_window, 1, 'omitnan'); % MAD locale
        sigmad  = 1.4826 * mad_loc;                           % ~sigma si gaussien
        sigmad(~isfinite(sigmad) | sigmad < 0) = NaN;
        noise_est(n,:) = sigmad;

        % ===== Ancienne version "résidu" (commentée) =====
        % r = sig - sig_sg;
        % med_r = movmedian(r, noise_window, 'omitnan');
        % mad_r = movmedian(abs(r - med_r), noise_window, 'omitnan');
        % noise_est(n,:) = 1.4826 * mad_r;
    end

    % ===== Résumé bruit par cellule =====
    noise_sigma = median(noise_est, 2, 'omitnan');
    noise_sigma(~isfinite(noise_sigma)) = snr_min_cap;
    noise_sigma = max(noise_sigma, snr_min_cap);

    % (optionnel) SNR “classique” juste pour inspection
    pHi = 99.5;
    A = prctile(DF_sg, pHi, 2) - prctile(DF_sg, 50, 2);
    A(~isfinite(A) | A < 0) = 0;
    SNR = A ./ noise_sigma;

    % ============================================================
    % SCORE basé UNIQUEMENT sur "bruit" (plus petit = meilleur)
    % -> on inverse pour que grand = bon
    % ============================================================
    score = 1 ./ noise_sigma;         % cellule “propre” -> score ↑
    score(~isfinite(score)) = 0;

    % --- Quality index (0..1) (normalisation robuste) ---
    s_valid = score(score > 0 & isfinite(score));
    if isempty(s_valid)
        quality_index = zeros(NCell,1);
        quality_min = 0; quality_max = 0; quality_thr0 = 0;
        return;
    end

    s_lo = prctile(s_valid, 5);
    s_hi = prctile(s_valid, 95);
    if ~isfinite(s_hi) || s_hi <= s_lo
        quality_index = zeros(NCell,1);
        quality_min = 0; quality_max = 1; quality_thr0 = 0;
        return;
    end

    quality_index = (score - s_lo) ./ (s_hi - s_lo);
    quality_index = min(1, max(0, quality_index));

    quality_min = 0;
    quality_max = 1;
    quality_thr0 = prctile(quality_index(isfinite(quality_index)), 25);
end

% function [DF, DF_sg, F0, noise_est, SNR, quality_index, quality_min, quality_max, quality_thr0] = ...
%     DF_processing(F, opts, fs)
% 
%     % --------- Params ---------
%     sg_win  = opts.savgol_win;
%     sg_poly = opts.savgol_poly;
% 
%     if nargin < 3 || isempty(fs) || ~isfinite(fs) || fs <= 0
%         fs = 20;
%     end
% 
%     % --- Fenêtre bruit (MAD sur résidu) : ~0.25 s ---
%     noise_window = round(0.25 * fs);
%     noise_window = max(11, min(41, noise_window));
%     if mod(noise_window,2)==0, noise_window = noise_window + 1; end
% 
%     snr_min_cap  = 1e-3;
% 
%     % --- Step 1: baseline + dF/F ---
%     [F0, DF] = baseline_calculation(F);
% 
%     [NCell, Nz] = size(DF);
% 
%     noise_window = min(noise_window, Nz);
%     if mod(noise_window,2)==0, noise_window = max(1, noise_window-1); end
% 
%     DF_sg     = nan(NCell, Nz);
%     noise_est = nan(NCell, Nz);
% 
%     % Fenêtre SavGol
%     sgN = max(sg_poly+2, round(sg_win));
%     if mod(sgN,2)==0, sgN = sgN+1; end
%     sgN = min(sgN, Nz - (mod(Nz,2)==0));     % <= Nz et impair
%     if sgN <= sg_poly
%         sgN = sg_poly + 1 + mod(sg_poly+1,2); % assure > sg_poly et impair
%         sgN = min(sgN, Nz - (mod(Nz,2)==0));
%     end
% 
%     for n = 1:NCell
%         sig = DF(n,:);
% 
%         % SavGol
%         sig_sg = sig;
%         if all(isfinite(sig)) && sgN >= (sg_poly+2) && sgN <= Nz
%             try
%                 sig_sg = sgolayfilt(sig, sg_poly, sgN);
%             catch
%                 sig_sg = sig;
%             end
%         else
%             % si NaN : tu peux soit interpoler, soit garder brut
%             % (ici: brut)
%             sig_sg = sig;
%         end
%         DF_sg(n,:) = sig_sg;
% 
%         % Résidu après lissage
%         r = sig - sig_sg;
% 
%         % sigma(t) via MAD locale sur r (ignore NaN)
%         med_r = movmedian(r, noise_window, 'omitnan');
%         mad_r = movmedian(abs(r - med_r), noise_window, 'omitnan');
%         sigmad = 1.4826 * mad_r;
% 
%         sigmad(~isfinite(sigmad) | sigmad < 0) = NaN;
%         noise_est(n,:) = sigmad;
%     end
% 
%     % ===== Estimation globale bruit =====
%     noise_sigma = median(noise_est, 2, 'omitnan');
%     noise_sigma(~isfinite(noise_sigma)) = snr_min_cap;
%     noise_sigma = max(noise_sigma, snr_min_cap);
% 
%     % Amplitude pic par rapport au bruit
%     pHi = 99.5;
%     A = prctile(DF_sg, pHi, 2) - prctile(DF_sg, 50, 2);
%     A(~isfinite(A) | A < 0) = 0;
% 
%     % Bulk global (IQR)
%     B = prctile(DF_sg, 75, 2) - prctile(DF_sg, 25, 2);
%     B(~isfinite(B) | B <= 0) = NaN;
% 
%     % Plancher robuste sur B (évite explosions de P)
%     B_valid = B(isfinite(B));
%     if isempty(B_valid)
%         B_floor = 1e-4;   % fallback dF/F
%     else
%         B_floor = prctile(B_valid, 5);
%     end
%     B = max(B, B_floor);
% 
%     % Scores
%     SNR = A ./ noise_sigma;
%     P   = A ./ B;
% 
%     P_thr  = 2.5;              % A doit être >= 2.5× bulk
%     P_gain = max(0, P / P_thr);
%     score  = SNR .* P_gain;
% 
%     % SNR → “est-ce que ça sort du bruit ?”
%     % P = A/B → “est-ce que ce sont des pics nets ou juste une dérive lente (indépendamment du bruit rapide) ?”
%     % P_gain → à quel point les pics dominent la structure lente => atout
%     % ou pénalité
% 
%     % --- Quality index (0..1) à partir du score ---
%     s = score;
%     s(~isfinite(s)) = 0;
%     s = max(0, s);
% 
%     s_valid = s(isfinite(s) & s > 0);
% 
%     if isempty(s_valid)
%         quality_index  = zeros(size(s));
%         quality_min = 0;
%         quality_max  = 0;
%         quality_thr0  = 0;
%     else
%         % Bornes robustes (tu peux mettre 1/99, 5/95 selon agressivité)
%         quality_min_s  = prctile(s_valid, 5);
%         quality_max_s  = prctile(s_valid, 95);
% 
%         % Évite division par ~0
%         quality_index_s  = (s - quality_min_s) ./ (quality_max_s - quality_min_s);
%         quality_index = min(1, max(0, quality_index_s));  % clamp [0,1]
%         quality_min = 0;
%         quality_max = 1;
%         quality_thr0 = prctile(quality_index(isfinite(quality_index)), 25);
%     end
% end

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
    ax      = getappdata(fig,'ax1');

    % Axe déviation (peut ne pas exister si ancien fig)
    axDev = [];
    if isappdata(fig,'axDev')
        axDev = getappdata(fig,'axDev');
    end

    cla(ax);
    if ~isempty(axDev) && ishghandle(axDev), cla(axDev); end

    x = DF_sg(cell_id,:);
    x = x(:).';
    T = numel(x);
    t = 1:T;

    xlim(ax,[1 max(1,T)]);
    plot(ax,t,x,'k-'); hold(ax,'on');
    xlabel(ax,'Frames'); ylabel(ax,'\DeltaF/F (SavGol)');

    % --- Déviation (subplot du bas) ---
    if ~isempty(axDev) && ishghandle(axDev)
        dev = [];
        if isappdata(fig,'deviation')
            dev = getappdata(fig,'deviation');
        end
    
        xlim(axDev,[1 max(1,T)]);
        if ~isempty(dev)
            dev = dev(:).';
            if numel(dev) ~= T
                dev = dev(1:min(end,T));
                if numel(dev) < T, dev(end+1:T) = NaN; end
            end
            
            %disp([numel(dev) T min(dev) max(dev)]);
            plot(axDev,t,dev,'k-'); hold(axDev,'on');
    
            % === scaling robuste pour voir la trace ===
            dv = dev(isfinite(dev));
            if ~isempty(dv)
                plot(axDev, t, dev, 'k-'); hold(axDev,'on');
                ylim(axDev,'auto');    % <-- laisse MATLAB gérer
            end
        end
    
        ylabel(axDev,'Dev');
        box(axDev,'on');
    end


    % --- Bandeaux bad frames sur les deux axes ---
    if isappdata(fig,'bad_frames')
        bad_frames = getappdata(fig,'bad_frames');
        draw_badframe_bands(ax, bad_frames, T);
        if ~isempty(axDev) && ishghandle(axDev)
            draw_badframe_bands(axDev, bad_frames, T);
        end
    end

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
    if isappdata(fig,'quality_index')
        quality_index = getappdata(fig,'quality_index');
        cid = getappdata(fig,'cell_id');
        qval = quality_index(cid);

        % Couleur basée sur q (0..1)
        if qval >= 0.75
            qcolor = [0.0 0.6 0.0];    % vert foncé
            qstyle = 'bold';
        elseif qval >= 0.55
            qcolor = [0.2 0.7 0.2];    % vert clair
            qstyle = 'normal';
        elseif qval >= 0.35
            qcolor = [0.9 0.6 0.1];    % orange
            qstyle = 'normal';
        else
            qcolor = [0.8 0.0 0.0];    % rouge
            qstyle = 'bold';
        end

        yMax = max(x,[],'omitnan');
        yMin = min(x,[],'omitnan');
        if ~isfinite(yMax), yMax = 1; end
        if ~isfinite(yMin), yMin = 0; end
        yPos = yMax - 0.05*(yMax - yMin);

        text(ax, 0.02*max(1,length(x)), yPos, sprintf('Qualité = %.2f %s', qval), ...
            'Color', qcolor, 'FontSize', 12, 'FontWeight', qstyle, ...
            'BackgroundColor',[1 1 1 0.6], 'Margin', 3);
    end
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
        if ~force_keep && quality_index(cid) < qthr % le seuil utilisé pour extraire les pics est celui du slider.
            Acttmp2{cid} = [];
            thresholds(cid) = NaN;
            Raster(cid,:) = false;
            DF_sg(cid,:) = NaN;
            fprintf('Cellule %d ignorée (qualité %.2f ≤ %.2f)\n', cid, quality_index(cid), qthr);
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
function update_quality_threshold(fig, thr)
    quality_index = getappdata(fig,'quality_index');
    cell_status   = getappdata(fig,'cell_status');

    % on ne navigue pas sur les cellules exclues manuellement
    valid_cells = find((quality_index >= thr) & (cell_status ~= -1));

    lbl = findobj(fig,'Tag','lbl_quality_thr');
    if ~isempty(lbl), lbl.String = sprintf('Quality threshold = %.2f',thr); end

    ax = getappdata(fig,'ax1');

    if isempty(valid_cells)
        setappdata(fig,'order_cells', []);
        setappdata(fig,'cell_index_in_order', []);
        cla(ax);
        title(ax, sprintf('Aucune cellule avec Quality >= %.2f (hors exclues)',thr));
        drawnow;
        return;
    end

    [~, ord] = sort(quality_index(valid_cells),'ascend');
    order_cells = valid_cells(ord);

    setappdata(fig,'order_cells', order_cells);
    setappdata(fig,'cell_index_in_order', 1);
    setappdata(fig,'cell_id', order_cells(1));
    setappdata(fig,'quality_thr', thr);
    setappdata(fig,'auto_intervals', []);
    if isappdata(fig,'thr_glo_last'), rmappdata(fig,'thr_glo_last'); end

    auto_detect_and_add(fig);
    refresh_data(fig);
    update_peak_histogram(fig);
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
    if isappdata(fig,'thr_event_last'), rmappdata(fig,'thr_event_last'); end
    auto_detect_and_add(fig);
    refresh_data(fig);
    update_peak_histogram(fig);
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
    if isappdata(fig,'thr_event_last'), rmappdata(fig,'thr_event_last'); end
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
    next_cell(fig);
end

function exclude_cell(fig)
    cid = getappdata(fig,'cell_id');
    st  = getappdata(fig,'cell_status');
    st(cid) = -1;
    setappdata(fig,'cell_status', st);
    next_cell(fig);
end

function finalize_and_close(fig, synchronous_frames)
    [invalid_cells, valid_cells, DF_sg, F0, Raster, Acttmp2, StartEnd, MAct, thresholds, opts, summary] = ...
        save_peak_matrix(fig, synchronous_frames);

    if iscell(Acttmp2) && size(Acttmp2,2) > 1, Acttmp2 = reshape(Acttmp2, [], 1); end
    if iscell(StartEnd) && size(StartEnd,2) > 1, StartEnd = reshape(StartEnd, [], 1); end

    setappdata(fig,'last_save_outputs', struct( ...
        'invalid_cells', invalid_cells, 'valid_cells', valid_cells, 'DF_sg', DF_sg, 'F0', F0, ...
        'Raster', Raster, 'Acttmp2', {Acttmp2}, 'StartEnd', {StartEnd}, 'MAct', MAct, ...
        'thresholds', thresholds, 'opts', opts, 'summary', summary));

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
        [DF, DF_sg, F0, noise_est, SNR, quality_index, quality_min, quality_max, quality_thr0] = DF_processing(F_raw, opts);

        setappdata(fig,'DF', DF);
        setappdata(fig,'DF_sg', DF_sg);
        setappdata(fig,'F0', F0);
        setappdata(fig,'noise_est', noise_est);
        setappdata(fig,'SNR', SNR);
        setappdata(fig,'quality_index', quality_index);

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

function draw_badframe_bands(ax, bad_frames, T)
    if isempty(ax) || ~ishghandle(ax) || T <= 0, return; end

    % bad_frames peut être:
    % - logique 1xT / Tx1
    % - indices (vector)
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

    if isempty(idx), return; end

    % Convertir idx en segments contigus [start end]
    d = diff(idx);
    cuts = [1 find(d>1)+1 numel(idx)+1];
    segs = zeros(numel(cuts)-1,2);
    for k=1:numel(cuts)-1
        a = idx(cuts(k));
        b = idx(cuts(k+1)-1);
        segs(k,:) = [a b];
    end

    yl = ylim(ax);
    y0 = yl(1); y1 = yl(2);

    % bandeau rouge transparent (sans bord)
    for k=1:size(segs,1)
        a = segs(k,1);
        b = segs(k,2);

        h = patch(ax, [a b b a], [y0 y0 y1 y1], [1 0 0], ...   % rouge pur
        'FaceAlpha', 0.30, ...                              % << plus visible (0.25–0.4)
        'EdgeColor', [0.6 0 0], ...                         % bordure rouge foncé
        'LineWidth', 0.6, ...
        'HitTest','off');
    
        set(h,'XLimInclude','off','YLimInclude','off');
        uistack(h,'bottom');      
        
        % Le bandeau ne doit PAS influencer les limites auto
        set(h, 'XLimInclude','off', 'YLimInclude','off');
        
        % Bandeau derrière la courbe
        uistack(h,'bottom');   
    end
end
