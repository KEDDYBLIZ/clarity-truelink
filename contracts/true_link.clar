;; TrueLink Contract
;; A decentralized system for verifying links with reviewer rewards

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-owner (err u100))
(define-constant err-not-reviewer (err u101))
(define-constant err-already-reviewed (err u102))
(define-constant err-invalid-score (err u103))
(define-constant err-insufficient-funds (err u104))
(define-constant reward-amount u10) ;; Amount in microSTX

;; Data Maps
(define-map reviewers principal bool)
(define-map domain-scores 
    {domain: (string-ascii 255)}
    {safe-votes: uint, unsafe-votes: uint, total-reviews: uint})
(define-map reviewer-reliability
    principal 
    {correct-reviews: uint, total-reviews: uint, rewards-claimed: uint})
(define-map link-reviews
    {link: (string-ascii 255), reviewer: principal}
    {verdict: bool, timestamp: uint, consensus: (optional bool)})
(define-map consensus-cache
    (string-ascii 255)
    {consensus: bool, confirmed-at: uint})

;; Public Functions
(define-public (register-reviewer (reviewer principal))
    (if (is-eq tx-sender contract-owner)
        (begin
            (map-set reviewers reviewer true)
            (map-set reviewer-reliability reviewer 
                {correct-reviews: u0, total-reviews: u0, rewards-claimed: u0})
            (ok true))
        err-not-owner))

(define-public (submit-review 
    (link (string-ascii 255))
    (domain (string-ascii 255))
    (is-safe bool))
    (let ((reviewer-status (default-to false (map-get? reviewers tx-sender)))
          (existing-review (map-get? link-reviews {link: link, reviewer: tx-sender})))
        (if (and reviewer-status (is-none existing-review))
            (begin
                (map-set link-reviews 
                    {link: link, reviewer: tx-sender}
                    {verdict: is-safe, timestamp: block-height, consensus: none})
                (update-domain-score domain is-safe)
                (update-consensus link)
                (ok true))
            err-not-reviewer)))

(define-public (claim-rewards)
    (let ((reviewer-data (default-to 
            {correct-reviews: u0, total-reviews: u0, rewards-claimed: u0}
            (map-get? reviewer-reliability tx-sender))))
        (if (> (get correct-reviews reviewer-data) (get rewards-claimed reviewer-data))
            (let ((pending-rewards (* (- (get correct-reviews reviewer-data) 
                                       (get rewards-claimed reviewer-data))
                                    reward-amount)))
                (if (>= (stx-get-balance (as-contract tx-sender)) pending-rewards)
                    (begin
                        (try! (as-contract (stx-transfer? pending-rewards tx-sender tx-sender)))
                        (map-set reviewer-reliability tx-sender
                            (merge reviewer-data {rewards-claimed: (get correct-reviews reviewer-data)}))
                        (ok pending-rewards))
                    err-insufficient-funds))
            (ok u0))))

;; Private Functions
(define-private (update-domain-score (domain (string-ascii 255)) (is-safe bool))
    (let ((current-score (default-to 
            {safe-votes: u0, unsafe-votes: u0, total-reviews: u0}
            (map-get? domain-scores {domain: domain}))))
        (map-set domain-scores
            {domain: domain}
            {
                safe-votes: (if is-safe 
                    (+ (get safe-votes current-score) u1)
                    (get safe-votes current-score)),
                unsafe-votes: (if is-safe
                    (get unsafe-votes current-score)
                    (+ (get unsafe-votes current-score) u1)),
                total-reviews: (+ (get total-reviews current-score) u1)
            })))

(define-private (update-consensus (link (string-ascii 255)))
    (let ((scores (get-link-scores link)))
        (if (>= (+ (get safe-votes scores) (get unsafe-votes scores)) u3)
            (let ((consensus (> (get safe-votes scores) (get unsafe-votes scores))))
                (map-set consensus-cache link 
                    {consensus: consensus, confirmed-at: block-height})
                (update-reviewer-stats link consensus)
                true)
            false)))

(define-private (update-reviewer-stats (link (string-ascii 255)) (consensus bool))
    (map delete-values ))

;; Read Only Functions
(define-read-only (get-domain-score (domain (string-ascii 255)))
    (ok (map-get? domain-scores {domain: domain})))

(define-read-only (is-reviewer (account principal))
    (ok (default-to false (map-get? reviewers account))))

(define-read-only (get-review 
    (link (string-ascii 255))
    (reviewer principal))
    (ok (map-get? link-reviews {link: link, reviewer: reviewer})))

(define-read-only (get-reviewer-stats (reviewer principal))
    (ok (map-get? reviewer-reliability reviewer)))

(define-read-only (get-link-consensus (link (string-ascii 255)))
    (ok (map-get? consensus-cache link)))
