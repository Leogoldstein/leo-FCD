function [cross_corr_gcamp_gcamp, cross_corr_gcamp_mtor, cross_corr_mtor_mtor] = ...
    compute_pairwise_corr(DF_gcamp, gcamp_output_folder, DF_all, mtor_indices)
% compute_pairwise_corr
% Fonction de calcul brut des corrélations pairwise.
%
% Inputs
%   DF_gcamp           : [nG x T] traces GCaMP
%   gcamp_output_folder: dossier session (optionnel, juste pour logs)
%   DF_all             : [nAll x T] traces combinées (GCaMP + mTOR/blue)
%   mtor_indices       : indices des cellules mTOR/blue dans DF_all
%
% Outputs
%   cross_corr_gcamp_gcamp : [nG x nG]
%   cross_corr_gcamp_mtor  : [nG_kept x nM_kept]
%   cross_corr_mtor_mtor   : [nM x nM]

    cross_corr_gcamp_gcamp = [];
    cross_corr_gcamp_mtor  = [];
    cross_corr_mtor_mtor   = [];

    try
        if nargin < 2 || isempty(gcamp_output_folder)
            gcamp_output_folder = '';
        else
            gcamp_output_folder = char(string(gcamp_output_folder));
        end

        % ======================================================
        % 1) GCaMP-GCaMP
        % ======================================================
        Xg = double(DF_gcamp);

        if ~isempty(Xg)
            keep_g = ~all(isnan(Xg), 2);
            Xg = Xg(keep_g, :);
        end

        if size(Xg,1) >= 2
            cross_corr_gcamp_gcamp = corrcoef(Xg');
        else
            cross_corr_gcamp_gcamp = [];
        end

        % ======================================================
        % 2) Si pas de données combinées -> stop ici
        % ======================================================
        if nargin < 3 || isempty(DF_all) || nargin < 4 || isempty(mtor_indices)
            return;
        end

        % ======================================================
        % 3) Préparer groupes GCaMP / mTOR depuis DF_all
        % ======================================================
        Xa = double(DF_all);
        if isempty(Xa)
            return;
        end

        mtor_indices = unique(round(mtor_indices(:)));
        mtor_indices = mtor_indices( ...
            isfinite(mtor_indices) & ...
            mtor_indices >= 1 & ...
            mtor_indices <= size(Xa,1));

        if isempty(mtor_indices)
            return;
        end

        all_idx = (1:size(Xa,1)).';
        gcamp_idx = setdiff(all_idx, mtor_indices, 'stable');

        Xg_all = Xa(gcamp_idx, :);
        Xm     = Xa(mtor_indices, :);

        keep_g2 = ~all(isnan(Xg_all), 2);
        keep_m  = ~all(isnan(Xm), 2);

        Xg_all = Xg_all(keep_g2, :);
        Xm     = Xm(keep_m, :);

        % ======================================================
        % 4) GCaMP-mTOR
        % ======================================================
        if ~isempty(Xg_all) && ~isempty(Xm)
            cross_corr_gcamp_mtor = pairwise_corr_two_groups(Xg_all, Xm);
        else
            cross_corr_gcamp_mtor = [];
        end

        % ======================================================
        % 5) mTOR-mTOR
        % ======================================================
        if size(Xm,1) >= 2
            cross_corr_mtor_mtor = corrcoef(Xm');
        else
            cross_corr_mtor_mtor = [];
        end

    catch ME
        disp("An error occurred for folder: " + string(gcamp_output_folder) + ...
             " - " + string(ME.message));
    end
end


function C = pairwise_corr_two_groups(X1, X2)
% pairwise_corr_two_groups
% Corrélation entre deux groupes de cellules
%
% Inputs
%   X1 : [n1 x T]
%   X2 : [n2 x T]
%
% Output
%   C  : [n1 x n2], C(i,j)=corr(X1(i,:), X2(j,:))

    n1 = size(X1,1);
    n2 = size(X2,1);

    C = nan(n1, n2);

    for i = 1:n1
        x = X1(i,:);

        for j = 1:n2
            y = X2(j,:);

            ok = isfinite(x) & isfinite(y);
            if nnz(ok) >= 2
                r = corrcoef(x(ok), y(ok));
                if numel(r) >= 4
                    C(i,j) = r(1,2);
                end
            end
        end
    end
end