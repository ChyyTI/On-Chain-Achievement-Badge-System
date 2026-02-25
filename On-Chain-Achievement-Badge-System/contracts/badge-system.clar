;; On-Chain Achievement Badge System
(define-constant platform-admin tx-sender)

;; Error codes
(define-constant err-unauthorized (err u700))
(define-constant err-badge-duplicate (err u701))
(define-constant err-badge-missing (err u702))
(define-constant err-badge-expired (err u703))
(define-constant err-badge-active (err u704))
(define-constant err-criteria-mismatch (err u705))
(define-constant err-not-inspector (err u706))
(define-constant err-not-issuer (err u707))
(define-constant err-recipient-registered (err u708))
(define-constant err-window-invalid (err u709))
(define-constant err-fingerprint-invalid (err u710))
(define-constant err-admin-only (err u711))
(define-constant err-award-closed (err u712))
(define-constant err-slug-empty (err u713))
(define-constant err-criteria-empty (err u714))
(define-constant err-tier-empty (err u715))

;; Badge registry
(define-map badges
  { badge-id: uint }
  {
    issuer: principal,
    badge-slug: (string-ascii 64),
    criteria: (string-ascii 256),
    tier: (string-ascii 256),
    created-block: uint,
    award-deadline: uint,
    fingerprint: uint,
    top-score: uint,
    top-recipient: (optional principal),
    award-open: bool,
    archived: bool
  }
)

(define-map recipient-entries
  { badge-id: uint, recipient: principal }
  { score: uint, enrolled-block: uint }
)

;; Badge counter
(define-data-var badge-counter uint u1)

;; Platform fee (basis points)
(define-data-var platform-fee-bps uint u100)

;; Queries

(define-read-only (get-badge (badge-id uint))
  (map-get? badges { badge-id: badge-id })
)

(define-read-only (get-recipient-entry (badge-id uint) (recipient principal))
  (map-get? recipient-entries { badge-id: badge-id, recipient: recipient })
)

(define-read-only (badge-registered (badge-id uint))
  (is-some (get-badge badge-id))
)

(define-read-only (award-window-open (badge-id uint))
  (match (get-badge badge-id)
    badge (and
             (get award-open badge)
             (< block-height (get award-deadline badge))
           )
    false
  )
)

(define-read-only (badge-past-deadline (badge-id uint))
  (match (get-badge badge-id)
    badge (>= block-height (get award-deadline badge))
    false
  )
)

(define-read-only (next-badge-id)
  (var-get badge-counter)
)

(define-read-only (get-platform-fee-bps)
  (var-get platform-fee-bps)
)

(define-read-only (estimate-platform-fee (amount uint))
  (/ (* amount (var-get platform-fee-bps)) u10000)
)

;; Helpers

(define-private (net-issuer-payout (amount uint))
  (- amount (estimate-platform-fee amount))
)

(define-private (slug-valid (slug (string-ascii 64)))
  (> (len slug) u0)
)

(define-private (criteria-valid (c (string-ascii 256)))
  (> (len c) u0)
)

(define-private (tier-valid (t (string-ascii 256)))
  (> (len t) u0)
)

;; Core operations

(define-public (create-badge
                (badge-slug (string-ascii 64))
                (criteria (string-ascii 256))
                (tier (string-ascii 256))
                (award-period uint)
                (fingerprint uint))
  (let ((badge-id (var-get badge-counter))
        (created-block block-height)
        (award-deadline (+ block-height award-period)))
    (begin
      (asserts! (slug-valid badge-slug) err-slug-empty)
      (asserts! (criteria-valid criteria) err-criteria-empty)
      (asserts! (tier-valid tier) err-tier-empty)
      (asserts! (> award-period u0) err-window-invalid)
      (asserts! (> fingerprint u0) err-fingerprint-invalid)

      (map-set badges
        { badge-id: badge-id }
        {
          issuer: tx-sender,
          badge-slug: badge-slug,
          criteria: criteria,
          tier: tier,
          created-block: created-block,
          award-deadline: award-deadline,
          fingerprint: fingerprint,
          top-score: u0,
          top-recipient: none,
          award-open: true,
          archived: false
        }
      )

      (var-set badge-counter (+ badge-id u1))

      (ok badge-id)
    )
  )
)

(define-public (submit-for-badge (badge-id uint) (score uint))
  (let ((badge (unwrap! (get-badge badge-id) err-badge-missing)))
    (begin
      (asserts! (get award-open badge) err-award-closed)
      (asserts! (< block-height (get award-deadline badge)) err-badge-expired)

      (asserts! (if (is-some (get top-recipient badge))
                   (> score (get top-score badge))
                   (>= score (get fingerprint badge)))
               err-criteria-mismatch)

      (map-set recipient-entries
        { badge-id: badge-id, recipient: tx-sender }
        { score: score, enrolled-block: block-height }
      )

      (map-set badges
        { badge-id: badge-id }
        (merge badge {
          top-score: score,
          top-recipient: (some tx-sender)
        })
      )

      (ok true)
    )
  )
)

(define-public (close-award-window (badge-id uint))
  (let ((badge (unwrap! (get-badge badge-id) err-badge-missing)))
    (begin
      (asserts! (is-eq tx-sender (get issuer badge)) err-not-issuer)
      (asserts! (get award-open badge) err-award-closed)
      (asserts! (< block-height (get award-deadline badge)) err-badge-expired)

      (map-set badges
        { badge-id: badge-id }
        (merge badge {
          award-open: false,
          award-deadline: block-height
        })
      )

      (ok true)
    )
  )
)

(define-public (archive-badge (badge-id uint))
  (let ((badge (unwrap! (get-badge badge-id) err-badge-missing)))
    (begin
      (asserts! (is-eq tx-sender (get issuer badge)) err-not-issuer)
      (asserts! (get award-open badge) err-award-closed)
      (asserts! (is-eq (get top-score badge) u0) err-criteria-mismatch)

      (map-set badges
        { badge-id: badge-id }
        (merge badge { award-open: false })
      )

      (ok true)
    )
  )
)

;; Platform governance

(define-public (set-platform-fee (new-fee-bps uint))
  (begin
    (asserts! (is-eq tx-sender platform-admin) err-admin-only)
    (asserts! (<= new-fee-bps u1000) err-unauthorized)
    (ok (var-set platform-fee-bps new-fee-bps))
  )
)