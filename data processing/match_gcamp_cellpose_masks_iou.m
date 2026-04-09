function [ ...
    matched_gcamp_true_idx, ...
    matched_cellpose_true_idx, ...
    matched_gcamp_false_idx, ...
    matched_cellpose_false_idx, ...
    gcamp_unmatched_idx, ...
    cellpose_unmatched_idx, ...
    is_cellpose_from_true_gcamp, ...
    IoU_matrix] = ...
    match_gcamp_cellpose_masks_iou( ...
        iscell_gcamp, ...
        gcamp_mask_true, ...
        gcamp_mask_false, ...
        mask_cellpose, ...
        iou_threshold)

% =========================================================
% NORMALISATION
% =========================================================
gcamp_mask_true  = normalize_mask_stack(gcamp_mask_true);
gcamp_mask_false = normalize_mask_stack(gcamp_mask_false);
mask_cellpose    = normalize_mask_stack(mask_cellpose);

% =========================================================
% HARMONISATION DES TAILLES [N H W]
% =========================================================
[H, W] = infer_hw(gcamp_mask_true, gcamp_mask_false, mask_cellpose);

gcamp_mask_true  = enforce_hw(gcamp_mask_true,  H, W);
gcamp_mask_false = enforce_hw(gcamp_mask_false, H, W);
mask_cellpose    = enforce_hw(mask_cellpose,    H, W);

N_true  = size(gcamp_mask_true,1);
N_false = size(gcamp_mask_false,1);
N_cp    = size(mask_cellpose,1);

% concat GCaMP
all_gcamp_masks = cat(1, gcamp_mask_true, gcamp_mask_false);
N_total = size(all_gcamp_masks,1);

% reshape
A = reshape(all_gcamp_masks, N_total, []);
B = reshape(mask_cellpose, N_cp, []);

A = double(A);
B = double(B);

% =========================================================
% CAS LIMITES
% =========================================================
if N_total == 0 || N_cp == 0
    IoU_matrix = zeros(N_total, N_cp);

    matched_gcamp_true_idx    = [];
    matched_cellpose_true_idx = [];
    matched_gcamp_false_idx   = [];
    matched_cellpose_false_idx = [];

    gcamp_unmatched_idx = (1:N_true)';
    cellpose_unmatched_idx = (1:N_cp)';

    is_cellpose_from_true_gcamp = false(N_cp,1);
    return;
end

% =========================================================
% IoU MATRIX
% =========================================================
intersection = A * B';
sumA = sum(A,2);
sumB = sum(B,2);

union = sumA + sumB' - intersection;
IoU_matrix = intersection ./ (union + eps);

% =========================================================
% MATCHING
% =========================================================
matched_gcamp = [];
matched_cellpose = [];

for i = 1:N_total
    [best_iou, j] = max(IoU_matrix(i,:));

    if best_iou >= iou_threshold
        matched_gcamp(end+1) = i; %#ok<AGROW>
        matched_cellpose(end+1) = j; %#ok<AGROW>
    end
end

% unique Cellpose
[matched_cellpose, ia] = unique(matched_cellpose);
matched_gcamp = matched_gcamp(ia);

% =========================================================
% SPLIT TRUE / FALSE
% =========================================================
is_true = matched_gcamp <= N_true;

matched_gcamp_true_idx     = matched_gcamp(is_true);
matched_cellpose_true_idx  = matched_cellpose(is_true);

matched_gcamp_false_idx    = matched_gcamp(~is_true) - N_true;
matched_cellpose_false_idx = matched_cellpose(~is_true);

% =========================================================
% UNMATCHED
% =========================================================
all_true_idx = (1:N_true)';
gcamp_unmatched_idx = setdiff(all_true_idx, matched_gcamp_true_idx);

all_cp_idx = (1:N_cp)';
cellpose_unmatched_idx = setdiff(all_cp_idx, matched_cellpose);

% =========================================================
% LABEL CELLPOSE
% =========================================================
is_cellpose_from_true_gcamp = false(N_cp,1);
is_cellpose_from_true_gcamp(matched_cellpose_true_idx) = true;

end

function M = normalize_mask_stack(M)

    if isempty(M)
        M = [];
        return;
    end

    if iscell(M)
        error('mask doit être stack [N H W]');
    end

    if ndims(M) ~= 3
        error('mask doit être 3D');
    end

    M = logical(M);
end

function [H, W] = infer_hw(varargin)
% Trouve la taille spatiale à partir du premier stack non vide

    H = [];
    W = [];

    for k = 1:nargin
        M = varargin{k};
        if ~isempty(M)
            sz = size(M);
            H = sz(2);
            W = sz(3);
            return;
        end
    end

    % si tout est vide
    H = 0;
    W = 0;
end

function M = enforce_hw(M, H, W)
% Convertit les vides en [0 H W] et vérifie la cohérence des non-vides

    if isempty(M)
        M = false(0, H, W);
        return;
    end

    sz = size(M);

    if sz(2) ~= H || sz(3) ~= W
        error('Dimensions spatiales incompatibles: attendu [%d %d], obtenu [%d %d].', ...
            H, W, sz(2), sz(3));
    end

    M = logical(M);
end