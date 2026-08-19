// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title   PatientRecordContract
 * @notice  A blockchain-based patient record management system for
 *          HealthCare Innovations Ltd., deployed via PRChain Solutions Ltd.
 * @dev     Implements role-based access control. Only the contract admin
 *          can authorise or revoke healthcare providers. Only authorised
 *          providers can add or transfer patient records.
 */
contract PatientRecordContract {

    // ─────────────────────────────────────────────────────────────
    //  State Variables
    // ─────────────────────────────────────────────────────────────

    /// @notice Address of the contract administrator (set at deployment)
    address public admin;

    /// @notice Running count of all patient records added to the contract
    uint256 public totalRecords;

    /// @notice Maps a provider's Ethereum address to their authorisation status
    mapping(address => bool) public authorisedProviders;

    /// @notice Maps a record ID to its full PatientRecord struct
    mapping(uint256 => PatientRecord) public patientRecords;

    /// @notice Maps a patient ID string to all their record IDs
    mapping(string => uint256[]) private patientHistory;


    // ─────────────────────────────────────────────────────────────
    //  Structs
    // ─────────────────────────────────────────────────────────────

    /**
     * @dev Stores all details related to a single patient record entry.
     *      recordHash is a SHA-256 hash of the full off-chain clinical data,
     *      used to verify data integrity without exposing sensitive information.
     */
    struct PatientRecord {
        uint256 recordId;        // Unique identifier for this record
        string  patientId;       // Hospital patient reference number
        string  providerName;    // Full name of the healthcare provider
        string  hospital;        // Name of the hospital or clinic
        string  diagnosisCode;   // ICD-10 diagnosis code
        bytes32 recordHash;      // SHA-256 hash of the full off-chain clinical data
        address currentProvider; // Ethereum address of the current record holder
        uint256 timestamp;       // Unix timestamp of when the record was created
        bool    isActive;        // Whether the record is currently active
    }


    // ─────────────────────────────────────────────────────────────
    //  Events
    // ─────────────────────────────────────────────────────────────

    /// @notice Emitted when a new patient record is successfully added
    event RecordAdded(
        uint256 indexed recordId,
        string  indexed patientId,
        address indexed provider,
        uint256         timestamp
    );

    /// @notice Emitted when a record is transferred between providers
    event RecordTransferred(
        uint256 indexed recordId,
        address indexed fromProvider,
        address indexed toProvider,
        uint256         timestamp
    );

    /// @notice Emitted when a provider is granted authorisation by the admin
    event ProviderAuthorised(address indexed provider, uint256 timestamp);

    /// @notice Emitted when a provider's authorisation is revoked by the admin
    event ProviderRevoked(address indexed provider, uint256 timestamp);


    // ─────────────────────────────────────────────────────────────
    //  Modifiers
    // ─────────────────────────────────────────────────────────────

    /**
     * @dev Restricts a function so only the admin address can call it.
     *      Reverts with a descriptive message if the caller is not the admin.
     */
    modifier onlyAdmin() {
        require(
            msg.sender == admin,
            "PatientRecordContract: caller is not the admin"
        );
        _;
    }

    /**
     * @dev Restricts a function so only addresses in the authorisedProviders
     *      mapping can call it. Reverts if the caller is not authorised.
     */
    modifier onlyAuthorised() {
        require(
            authorisedProviders[msg.sender],
            "PatientRecordContract: caller is not an authorised provider"
        );
        _;
    }

    /**
     * @dev Validates that a given record ID exists and is active before
     *      allowing a function to proceed.
     */
    modifier recordExists(uint256 _recordId) {
        require(
            _recordId > 0 && _recordId <= totalRecords,
            "PatientRecordContract: record ID does not exist"
        );
        require(
            patientRecords[_recordId].isActive,
            "PatientRecordContract: record is no longer active"
        );
        _;
    }


    // ─────────────────────────────────────────────────────────────
    //  Constructor
    // ─────────────────────────────────────────────────────────────

    /**
     * @dev Sets the deploying address as the admin and initialises
     *      totalRecords to zero. The admin is also automatically
     *      added as an authorised provider.
     */
    constructor() {
        admin                        = msg.sender;
        totalRecords                 = 0;
        authorisedProviders[admin]   = true;

        emit ProviderAuthorised(admin, block.timestamp);
    }


    // ─────────────────────────────────────────────────────────────
    //  Admin Functions
    // ─────────────────────────────────────────────────────────────

    /**
     * @notice Grants record management rights to a healthcare provider.
     * @dev    Can only be called by the admin. Emits ProviderAuthorised.
     * @param  _provider The Ethereum address of the provider to authorise.
     */
    function authoriseProvider(address _provider) external onlyAdmin {
        require(
            _provider != address(0),
            "PatientRecordContract: invalid provider address"
        );
        require(
            !authorisedProviders[_provider],
            "PatientRecordContract: provider is already authorised"
        );

        authorisedProviders[_provider] = true;

        emit ProviderAuthorised(_provider, block.timestamp);
    }

    /**
     * @notice Revokes record management rights from a healthcare provider.
     * @dev    Can only be called by the admin. Admin cannot revoke themselves.
     *         Emits ProviderRevoked.
     * @param  _provider The Ethereum address of the provider to revoke.
     */
    function revokeProvider(address _provider) external onlyAdmin {
        require(
            _provider != admin,
            "PatientRecordContract: admin cannot revoke their own access"
        );
        require(
            authorisedProviders[_provider],
            "PatientRecordContract: provider is not currently authorised"
        );

        authorisedProviders[_provider] = false;

        emit ProviderRevoked(_provider, block.timestamp);
    }


    // ─────────────────────────────────────────────────────────────
    //  Core Record Functions
    // ─────────────────────────────────────────────────────────────

    /**
     * @notice Adds a new patient record to the blockchain.
     * @dev    Only authorised providers may call this function.
     *         totalRecords is incremented before assignment to
     *         ensure record IDs start at 1 (never 0).
     *         Emits RecordAdded on success.
     *
     * @param  _patientId     Hospital patient reference number (e.g. "P001")
     * @param  _providerName  Full name of the adding provider (e.g. "Dr. Smith")
     * @param  _hospital      Name of the hospital or clinic
     * @param  _diagnosisCode ICD-10 diagnosis code (e.g. "J18.9")
     * @param  _recordHash    SHA-256 hash of the full off-chain clinical document
     *
     * @return newRecordId    The ID assigned to the newly created record
     */
    function addRecord(
        string  memory _patientId,
        string  memory _providerName,
        string  memory _hospital,
        string  memory _diagnosisCode,
        bytes32        _recordHash
    )
        external
        onlyAuthorised
        returns (uint256 newRecordId)
    {
        // Validate that no required string fields are empty
        require(bytes(_patientId).length     > 0, "PatientRecordContract: patient ID required");
        require(bytes(_providerName).length  > 0, "PatientRecordContract: provider name required");
        require(bytes(_hospital).length      > 0, "PatientRecordContract: hospital name required");
        require(bytes(_diagnosisCode).length > 0, "PatientRecordContract: diagnosis code required");

        // Increment counter first so IDs begin at 1
        totalRecords++;
        newRecordId = totalRecords;

        // Build and store the new record
        patientRecords[newRecordId] = PatientRecord({
            recordId        : newRecordId,
            patientId       : _patientId,
            providerName    : _providerName,
            hospital        : _hospital,
            diagnosisCode   : _diagnosisCode,
            recordHash      : _recordHash,
            currentProvider : msg.sender,
            timestamp       : block.timestamp,
            isActive        : true
        });

        // Append this record ID to the patient's history
        patientHistory[_patientId].push(newRecordId);

        emit RecordAdded(newRecordId, _patientId, msg.sender, block.timestamp);

        return newRecordId;
    }

    /**
     * @notice Transfers custody of a patient record to another authorised provider.
     * @dev    Both the caller and the recipient must be authorised providers.
     *         Only the current record holder can initiate a transfer.
     *         Emits RecordTransferred on success.
     *
     * @param  _recordId    The ID of the record to transfer
     * @param  _toProvider  Ethereum address of the receiving provider
     */
    function transferRecord(
        uint256 _recordId,
        address _toProvider
    )
        external
        onlyAuthorised
        recordExists(_recordId)
    {
        PatientRecord storage record = patientRecords[_recordId];

        // Only the current holder of the record can transfer it
        require(
            record.currentProvider == msg.sender,
            "PatientRecordContract: only the current record holder can transfer"
        );

        // The receiving provider must also be authorised
        require(
            authorisedProviders[_toProvider],
            "PatientRecordContract: recipient is not an authorised provider"
        );

        // Prevent transferring to the same address
        require(
            _toProvider != msg.sender,
            "PatientRecordContract: cannot transfer record to yourself"
        );

        address previousProvider    = record.currentProvider;
        record.currentProvider      = _toProvider;

        emit RecordTransferred(_recordId, previousProvider, _toProvider, block.timestamp);
    }


    // ─────────────────────────────────────────────────────────────
    //  View / Query Functions
    // ─────────────────────────────────────────────────────────────

    /**
     * @notice Retrieves the full details of a single patient record.
     * @dev    Read-only. Accessible to any caller (public data on-chain).
     * @param  _recordId  The ID of the record to retrieve.
     * @return            The full PatientRecord struct for that ID.
     */
    function getRecord(uint256 _recordId)
        external
        view
        recordExists(_recordId)
        returns (PatientRecord memory)
    {
        return patientRecords[_recordId];
    }

    /**
     * @notice Returns all record IDs associated with a given patient.
     * @dev    Read-only. Uses the patientHistory mapping.
     * @param  _patientId  The patient reference string to look up.
     * @return             An array of record IDs belonging to that patient.
     */
    function getPatientHistory(string memory _patientId)
        external
        view
        returns (uint256[] memory)
    {
        return patientHistory[_patientId];
    }

    /**
     * @notice Checks whether a given address is an authorised provider.
     * @param  _provider  The Ethereum address to check.
     * @return            True if authorised, false otherwise.
     */
    function isAuthorised(address _provider)
        external
        view
        returns (bool)
    {
        return authorisedProviders[_provider];
    }
}
