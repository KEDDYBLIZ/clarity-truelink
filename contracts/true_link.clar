;; TrueLink Contract
;; A decentralized system for verifying links

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-owner (err u100))
(define-constant err-not-reviewer (err u101))
(define-constant err-already-reviewed (err u102))
(define-constant err-invalid-score (err u103))

;; Data Maps
(define-map reviewers principal bool)
(define-map domain-scores 
    {domain: (string-ascii 255)}
    {safe-votes: uint, unsafe-votes: uint, total-reviews: uint})
(define-map reviewer-reliability
    principal 
    {correct-reviews: uint, total-reviews: uint})
(define-map link-reviews
    {link: (string-ascii 255), reviewer: principal}
    {verdict: bool, timestamp: uint})

;; Public Functions
(define-public (register-reviewer (reviewer principal))
    (if (is-eq tx-sender contract-owner)
        (begin
            (map-set reviewers reviewer true)
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
                    {verdict: is-safe, timestamp: block-height})
                (update-domain-score domain is-safe)
                (ok true))
            err-not-reviewer)))

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

;; Read Only Functions
(define-read-only (get-domain-score (domain (string-ascii 255)))
    (ok (map-get? domain-scores {domain: domain})))

(define-read-only (is-reviewer (account principal))
    (ok (default-to false (map-get? reviewers account))))

(define-read-only (get-review 
    (link (string-ascii 255))
    (reviewer principal))
    (ok (map-get? link-reviews {link: link, reviewer: reviewer})))