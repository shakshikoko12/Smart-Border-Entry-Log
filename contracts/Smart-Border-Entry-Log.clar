(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_INVALID_ENTRY (err u402))
(define-constant ERR_ENTRY_NOT_FOUND (err u404))
(define-constant ERR_ALREADY_EXITED (err u405))

(define-constant ERR_HEALTH_OFFICER_UNAUTHORIZED (err u406))
(define-constant ERR_INVALID_HEALTH_STATUS (err u407))
(define-constant ERR_HEALTH_DECLARATION_EXISTS (err u408))

(define-constant ERR_RISK_UNAUTHORIZED (err u409))
(define-constant ERR_INVALID_RISK_SCORE (err u410))
(define-constant ERR_RISK_ASSESSMENT_EXISTS (err u411))
(define-constant HIGH_RISK_THRESHOLD u75)
(define-constant MEDIUM_RISK_THRESHOLD u50)

(define-constant ERR_INVALID_REPUTATION_CHANGE (err u414))
(define-constant REPUTATION_TIER_BRONZE u25)
(define-constant REPUTATION_TIER_SILVER u50)
(define-constant REPUTATION_TIER_GOLD u75)

(define-data-var next-entry-id uint u1)

(define-map authorized-agents principal bool)
(define-map border-entries uint {
    traveler: principal,
    entry-point: (string-ascii 50),
    destination: (string-ascii 50),
    entry-type: (string-ascii 10),
    timestamp: uint,
    block-height: uint,
    status: (string-ascii 10),
    exit-timestamp: (optional uint),
    exit-point: (optional (string-ascii 50))
})

(define-map traveler-entries principal (list 100 uint))
(define-map entry-statistics (string-ascii 50) {
    total-entries: uint,
    total-exits: uint,
    active-travelers: uint
})

(define-public (add-authorized-agent (agent principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (map-set authorized-agents agent true)
        (ok true)
    )
)

(define-public (remove-authorized-agent (agent principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (map-delete authorized-agents agent)
        (ok true)
    )
)

(define-public (log-entry (traveler principal) (entry-point (string-ascii 50)) (destination (string-ascii 50)) (entry-type (string-ascii 10)))
    (let (
        (entry-id (var-get next-entry-id))
        (current-block stacks-block-height)
        (current-entries (default-to (list) (map-get? traveler-entries traveler)))
        (current-stats (default-to {total-entries: u0, total-exits: u0, active-travelers: u0} (map-get? entry-statistics entry-point)))
    )
        (asserts! (default-to false (map-get? authorized-agents tx-sender)) ERR_UNAUTHORIZED)
        (asserts! (> (len entry-point) u0) ERR_INVALID_ENTRY)
        (asserts! (> (len destination) u0) ERR_INVALID_ENTRY)
        (asserts! (or (is-eq entry-type "entry") (is-eq entry-type "transit")) ERR_INVALID_ENTRY)
        
        (map-set border-entries entry-id {
            traveler: traveler,
            entry-point: entry-point,
            destination: destination,
            entry-type: entry-type,
            timestamp: stacks-block-height,
            block-height: current-block,
            status: "active",
            exit-timestamp: none,
            exit-point: none
        })
        
        (map-set traveler-entries traveler (unwrap! (as-max-len? (append current-entries entry-id) u100) ERR_INVALID_ENTRY))
        
        (map-set entry-statistics entry-point {
            total-entries: (+ (get total-entries current-stats) u1),
            total-exits: (get total-exits current-stats),
            active-travelers: (+ (get active-travelers current-stats) u1)
        })
        
        (var-set next-entry-id (+ entry-id u1))
        (ok entry-id)
    )
)

(define-public (log-exit (entry-id uint) (exit-point (string-ascii 50)))
    (let (
        (entry-data (unwrap! (map-get? border-entries entry-id) ERR_ENTRY_NOT_FOUND))
        (entry-point-name (get entry-point entry-data))
        (current-stats (default-to {total-entries: u0, total-exits: u0, active-travelers: u0} (map-get? entry-statistics entry-point-name)))
    )
        (asserts! (default-to false (map-get? authorized-agents tx-sender)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status entry-data) "active") ERR_ALREADY_EXITED)
        (asserts! (> (len exit-point) u0) ERR_INVALID_ENTRY)
        
        (map-set border-entries entry-id (merge entry-data {
            status: "exited",
            exit-timestamp: (some stacks-block-height),
            exit-point: (some exit-point)
        }))
        
        (map-set entry-statistics entry-point-name {
            total-entries: (get total-entries current-stats),
            total-exits: (+ (get total-exits current-stats) u1),
            active-travelers: (- (get active-travelers current-stats) u1)
        })
        
        (ok true)
    )
)

(define-public (update-entry-status (entry-id uint) (new-status (string-ascii 10)))
    (let (
        (entry-data (unwrap! (map-get? border-entries entry-id) ERR_ENTRY_NOT_FOUND))
    )
        (asserts! (default-to false (map-get? authorized-agents tx-sender)) ERR_UNAUTHORIZED)
        (asserts! (or (is-eq new-status "active") (is-eq new-status "flagged") (is-eq new-status "cleared")) ERR_INVALID_ENTRY)
        
        (map-set border-entries entry-id (merge entry-data {status: new-status}))
        (ok true)
    )
)

(define-read-only (get-entry (entry-id uint))
    (map-get? border-entries entry-id)
)

(define-read-only (get-traveler-entries (traveler principal))
    (default-to (list) (map-get? traveler-entries traveler))
)

(define-read-only (get-entry-statistics (entry-point (string-ascii 50)))
    (default-to {total-entries: u0, total-exits: u0, active-travelers: u0} (map-get? entry-statistics entry-point))
)

(define-read-only (is-authorized-agent (agent principal))
    (default-to false (map-get? authorized-agents agent))
)

(define-read-only (get-contract-owner)
    CONTRACT_OWNER
)

(define-read-only (get-next-entry-id)
    (var-get next-entry-id)
)

(define-read-only (get-traveler-active-entries (traveler principal))
    (let (
        (entry-ids (get-traveler-entries traveler))
    )
        (filter is-entry-active entry-ids)
    )
)

(define-private (is-entry-active (entry-id uint))
    (match (map-get? border-entries entry-id)
        entry-data (is-eq (get status entry-data) "active")
        false
    )
)

(define-read-only (get-entry-point-active-count (entry-point (string-ascii 50)))
    (get active-travelers (get-entry-statistics entry-point))
)

(define-read-only (get-traveler-last-entry (traveler principal))
    (let (
        (entries (get-traveler-entries traveler))
    )
        (if (> (len entries) u0)
            (match (element-at entries (- (len entries) u1))
                last-entry-id (map-get? border-entries last-entry-id)
                none
            )
            none
        )
    )
)

(map-set authorized-agents CONTRACT_OWNER true)


(define-map authorized-health-officers principal bool)
(define-map health-declarations uint {
    declaration-type: (string-ascii 20),
    health-status: (string-ascii 15),
    temperature: (optional uint),
    symptoms: (string-ascii 100),
    clearance-status: (string-ascii 10),
    officer: principal,
    declaration-timestamp: uint,
    clearance-timestamp: (optional uint)
})

(define-map entry-health-mapping uint uint)

(define-public (add-health-officer (officer principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (map-set authorized-health-officers officer true)
        (ok true)
    )
)

(define-public (record-health-declaration 
    (entry-id uint) 
    (declaration-type (string-ascii 20))
    (health-status (string-ascii 15))
    (temperature (optional uint))
    (symptoms (string-ascii 100)))
    (begin
        (asserts! (default-to false (map-get? authorized-health-officers tx-sender)) ERR_HEALTH_OFFICER_UNAUTHORIZED)
        (asserts! (is-some (map-get? border-entries entry-id)) ERR_ENTRY_NOT_FOUND)
        (asserts! (is-none (map-get? entry-health-mapping entry-id)) ERR_HEALTH_DECLARATION_EXISTS)
        (asserts! (or (is-eq health-status "healthy") (is-eq health-status "symptomatic") (is-eq health-status "fever")) ERR_INVALID_HEALTH_STATUS)
        
        (map-set health-declarations entry-id {
            declaration-type: declaration-type,
            health-status: health-status,
            temperature: temperature,
            symptoms: symptoms,
            clearance-status: "pending",
            officer: tx-sender,
            declaration-timestamp: stacks-block-height,
            clearance-timestamp: none
        })
        
        (map-set entry-health-mapping entry-id entry-id)
        (ok entry-id)
    )
)

(define-public (update-health-clearance (entry-id uint) (clearance-status (string-ascii 10)))
    (let (
        (health-data (unwrap! (map-get? health-declarations entry-id) ERR_ENTRY_NOT_FOUND))
    )
        (asserts! (default-to false (map-get? authorized-health-officers tx-sender)) ERR_HEALTH_OFFICER_UNAUTHORIZED)
        (asserts! (or (is-eq clearance-status "cleared") (is-eq clearance-status "rejected") (is-eq clearance-status "quarantine")) ERR_INVALID_HEALTH_STATUS)
        
        (map-set health-declarations entry-id (merge health-data {
            clearance-status: clearance-status,
            clearance-timestamp: (some stacks-block-height)
        }))
        (ok true)
    )
)

(define-read-only (get-health-declaration (entry-id uint))
    (map-get? health-declarations entry-id)
)

(define-read-only (is-health-officer (officer principal))
    (default-to false (map-get? authorized-health-officers officer))
)

(define-read-only (get-entry-health-status (entry-id uint))
    (match (map-get? health-declarations entry-id)
        health-data (some (get clearance-status health-data))
        none
    )
)


(define-map authorized-risk-officers principal bool)
(define-map traveler-risk-profiles principal {
    current-risk-score: uint,
    total-assessments: uint,
    high-risk-incidents: uint,
    last-assessment-timestamp: uint,
    alert-status: (string-ascii 15)
})
(define-map risk-assessments uint {
    traveler: principal,
    entry-id: uint,
    risk-score: uint,
    risk-factors: (string-ascii 200),
    assessed-by: principal,
    assessment-timestamp: uint,
    severity-level: (string-ascii 10)
})
(define-data-var next-risk-assessment-id uint u1)
(define-map risk-statistics (string-ascii 20) uint)

(define-public (authorize-risk-officer (officer principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (map-set authorized-risk-officers officer true)
        (ok true)
    )
)

(define-public (assess-traveler-risk (traveler principal) (entry-id uint) (risk-score uint) (risk-factors (string-ascii 200)))
    (let (
        (assessment-id (var-get next-risk-assessment-id))
        (current-profile (default-to {current-risk-score: u0, total-assessments: u0, high-risk-incidents: u0, last-assessment-timestamp: u0, alert-status: "none"} (map-get? traveler-risk-profiles traveler)))
        (severity (if (>= risk-score HIGH_RISK_THRESHOLD) "high" (if (>= risk-score MEDIUM_RISK_THRESHOLD) "medium" "low")))
        (alert-status (if (>= risk-score HIGH_RISK_THRESHOLD) "high-risk" (if (>= risk-score MEDIUM_RISK_THRESHOLD) "watch-list" "cleared")))
        (high-risk-count (if (>= risk-score HIGH_RISK_THRESHOLD) (+ (get high-risk-incidents current-profile) u1) (get high-risk-incidents current-profile)))
    )
        (asserts! (default-to false (map-get? authorized-risk-officers tx-sender)) ERR_RISK_UNAUTHORIZED)
        (asserts! (<= risk-score u100) ERR_INVALID_RISK_SCORE)
        (asserts! (is-some (map-get? border-entries entry-id)) ERR_ENTRY_NOT_FOUND)
        
        (map-set risk-assessments assessment-id {
            traveler: traveler,
            entry-id: entry-id,
            risk-score: risk-score,
            risk-factors: risk-factors,
            assessed-by: tx-sender,
            assessment-timestamp: stacks-block-height,
            severity-level: severity
        })
        
        (map-set traveler-risk-profiles traveler {
            current-risk-score: risk-score,
            total-assessments: (+ (get total-assessments current-profile) u1),
            high-risk-incidents: high-risk-count,
            last-assessment-timestamp: stacks-block-height,
            alert-status: alert-status
        })
        
        (map-set risk-statistics severity (+ (default-to u0 (map-get? risk-statistics severity)) u1))
        (var-set next-risk-assessment-id (+ assessment-id u1))
        (ok assessment-id)
    )
)

(define-read-only (get-traveler-risk-profile (traveler principal))
    (map-get? traveler-risk-profiles traveler)
)

(define-read-only (get-risk-assessment (assessment-id uint))
    (map-get? risk-assessments assessment-id)
)

(define-read-only (is-high-risk-traveler (traveler principal))
    (match (map-get? traveler-risk-profiles traveler)
        profile (>= (get current-risk-score profile) HIGH_RISK_THRESHOLD)
        false
    )
)

(define-read-only (get-risk-statistics-by-severity (severity (string-ascii 10)))
    (default-to u0 (map-get? risk-statistics severity))
)

(define-constant ERR_COOLDOWN_VIOLATION (err u412))
(define-constant ERR_INVALID_POLICY (err u413))

(define-map entry-cooldown-policies (string-ascii 20) uint)
(define-map traveler-frequency-stats principal {
    total-crossings: uint,
    average-interval: uint,
    shortest-interval: uint,
    longest-interval: uint,
    last-entry-block: uint
})

(define-public (set-entry-cooldown-policy (policy-name (string-ascii 20)) (min-blocks uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (> min-blocks u0) ERR_INVALID_POLICY)
        (map-set entry-cooldown-policies policy-name min-blocks)
        (ok true)
    )
)

(define-public (validate-entry-timing (traveler principal) (policy-name (string-ascii 20)))
    (let (
        (cooldown-blocks (unwrap! (map-get? entry-cooldown-policies policy-name) ERR_INVALID_POLICY))
        (stats (map-get? traveler-frequency-stats traveler))
        (current-block stacks-block-height)
    )
        (match stats
            traveler-stats
                (let (
                    (blocks-since-last (- current-block (get last-entry-block traveler-stats)))
                )
                    (asserts! (>= blocks-since-last cooldown-blocks) ERR_COOLDOWN_VIOLATION)
                    (ok {allowed: true, blocks-since-last: blocks-since-last, required-cooldown: cooldown-blocks})
                )
            (ok {allowed: true, blocks-since-last: u0, required-cooldown: cooldown-blocks})
        )
    )
)

(define-public (update-frequency-stats (traveler principal))
    (let (
        (current-block stacks-block-height)
        (existing-stats (map-get? traveler-frequency-stats traveler))
    )
        (asserts! (default-to false (map-get? authorized-agents tx-sender)) ERR_UNAUTHORIZED)
        (match existing-stats
            stats
                (let (
                    (interval (- current-block (get last-entry-block stats)))
                    (new-total (+ (get total-crossings stats) u1))
                    (new-avg (/ (+ (* (get average-interval stats) (get total-crossings stats)) interval) new-total))
                    (new-shortest (if (< interval (get shortest-interval stats)) interval (get shortest-interval stats)))
                    (new-longest (if (> interval (get longest-interval stats)) interval (get longest-interval stats)))
                )
                    (map-set traveler-frequency-stats traveler {
                        total-crossings: new-total,
                        average-interval: new-avg,
                        shortest-interval: new-shortest,
                        longest-interval: new-longest,
                        last-entry-block: current-block
                    })
                    (ok true)
                )
            (begin
                (map-set traveler-frequency-stats traveler {
                    total-crossings: u1,
                    average-interval: u0,
                    shortest-interval: u999999,
                    longest-interval: u0,
                    last-entry-block: current-block
                })
                (ok true)
            )
        )
    )
)

(define-read-only (get-entry-frequency-stats (traveler principal))
    (map-get? traveler-frequency-stats traveler)
)

(define-read-only (get-cooldown-policy (policy-name (string-ascii 20)))
    (map-get? entry-cooldown-policies policy-name)
)

(define-read-only (get-time-until-eligible (traveler principal) (policy-name (string-ascii 20)))
    (match (map-get? entry-cooldown-policies policy-name)
        cooldown-blocks
            (match (map-get? traveler-frequency-stats traveler)
                stats
                    (let (
                        (blocks-since (- stacks-block-height (get last-entry-block stats)))
                        (remaining (if (>= blocks-since cooldown-blocks) u0 (- cooldown-blocks blocks-since)))
                    )
                        (some remaining)
                    )
                (some u0)
            )
        none
    )
)

(define-map traveler-reputation principal {
    trust-score: uint,
    successful-crossings: uint,
    violations: uint,
    compliance-rate: uint,
    tier-level: (string-ascii 10),
    fast-track-eligible: bool,
    last-updated: uint
})

(define-map reputation-tiers (string-ascii 10) {
    min-score: uint,
    crossing-bonus: uint,
    violation-penalty: uint
})

(define-public (initialize-reputation-tiers)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (map-set reputation-tiers "bronze" {min-score: u0, crossing-bonus: u2, violation-penalty: u5})
        (map-set reputation-tiers "silver" {min-score: REPUTATION_TIER_BRONZE, crossing-bonus: u3, violation-penalty: u7})
        (map-set reputation-tiers "gold" {min-score: REPUTATION_TIER_SILVER, crossing-bonus: u5, violation-penalty: u10})
        (map-set reputation-tiers "platinum" {min-score: REPUTATION_TIER_GOLD, crossing-bonus: u8, violation-penalty: u15})
        (ok true)
    )
)

(define-public (update-reputation-score (traveler principal) (change-type (string-ascii 15)))
    (let (
        (current-rep (default-to {trust-score: u50, successful-crossings: u0, violations: u0, compliance-rate: u100, tier-level: "bronze", fast-track-eligible: false, last-updated: u0} (map-get? traveler-reputation traveler)))
        (is-success (is-eq change-type "success"))
        (is-violation (is-eq change-type "violation"))
        (new-crossings (if is-success (+ (get successful-crossings current-rep) u1) (get successful-crossings current-rep)))
        (new-violations (if is-violation (+ (get violations current-rep) u1) (get violations current-rep)))
        (total-events (+ new-crossings new-violations))
        (new-compliance (if (> total-events u0) (/ (* new-crossings u100) total-events) u100))
        (score-change (if is-success u5 (if is-violation (- u0 u8) u0)))
        (new-score-raw (if is-success (+ (get trust-score current-rep) u5) (if (>= (get trust-score current-rep) u8) (- (get trust-score current-rep) u8) u0)))
        (new-score (if (> new-score-raw u100) u100 new-score-raw))
        (tier (if (>= new-score REPUTATION_TIER_GOLD) "platinum" (if (>= new-score REPUTATION_TIER_SILVER) "gold" (if (>= new-score REPUTATION_TIER_BRONZE) "silver" "bronze"))))
        (fast-track (>= new-score REPUTATION_TIER_SILVER))
    )
        (asserts! (default-to false (map-get? authorized-agents tx-sender)) ERR_UNAUTHORIZED)
        (asserts! (or is-success is-violation) ERR_INVALID_REPUTATION_CHANGE)
        
        (map-set traveler-reputation traveler {
            trust-score: new-score,
            successful-crossings: new-crossings,
            violations: new-violations,
            compliance-rate: new-compliance,
            tier-level: tier,
            fast-track-eligible: fast-track,
            last-updated: stacks-block-height
        })
        (ok new-score)
    )
)

(define-read-only (get-traveler-reputation (traveler principal))
    (map-get? traveler-reputation traveler)
)

(define-read-only (is-fast-track-eligible (traveler principal))
    (match (map-get? traveler-reputation traveler)
        rep-data (get fast-track-eligible rep-data)
        false
    )
)

(define-read-only (get-reputation-tier-benefits (tier-name (string-ascii 10)))
    (map-get? reputation-tiers tier-name)
)