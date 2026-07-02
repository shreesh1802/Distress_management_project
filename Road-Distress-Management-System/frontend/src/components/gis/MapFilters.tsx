import { useState } from 'react';
import { Filter, SlidersHorizontal } from 'lucide-react';

export interface MapFilterState {
  road: string;
  severity: string;
  district: string;
  status: string;
}

interface MapFiltersProps {
  filters: MapFilterState;
  onFilterChange: (newFilters: MapFilterState) => void;
  allDistricts: string[];
}

export default function MapFilters({ filters, onFilterChange, allDistricts }: MapFiltersProps) {
  const [isOpen, setIsOpen] = useState(false);

  const handleSelectChange = (field: keyof MapFilterState, value: string) => {
    onFilterChange({
      ...filters,
      [field]: value,
    });
  };

  const handleReset = () => {
    onFilterChange({
      road: 'all',
      severity: 'all',
      district: 'all',
      status: 'all',
    });
  };

  const isFiltered =
    filters.road !== 'all' ||
    filters.severity !== 'all' ||
    filters.district !== 'all' ||
    filters.status !== 'all';

  return (
    <div className="floating-filters">
      <button
        type="button"
        className={`floating-filters__trigger-btn ${isOpen ? 'active' : ''} ${
          isFiltered ? 'highlighted' : ''
        }`}
        onClick={() => setIsOpen(!isOpen)}
        title="Toggle Map Filters"
      >
        <SlidersHorizontal size={14} />
        <span>Filters</span>
      </button>

      {isOpen && (
        <div className="floating-filters__dropdown animate-slide-in">
          <header className="floating-filters__header">
            <div className="floating-filters__title-group">
              <Filter size={13} />
              <span>Map Overlay Filters</span>
            </div>
            {isFiltered && (
              <button
                type="button"
                className="floating-filters__reset-btn"
                onClick={handleReset}
              >
                Reset
              </button>
            )}
          </header>

          <div className="floating-filters__body">
            {/* Filter by Highway Road */}
            <div className="floating-filters__control">
              <label className="floating-filters__label">Road Corridor</label>
              <select
                className="floating-filters__select"
                value={filters.road}
                onChange={(e) => handleSelectChange('road', e.target.value)}
              >
                <option value="all">All Corridors</option>
                <option value="NH-48">NH-48</option>
                <option value="NH-44">NH-44</option>
              </select>
            </div>

            {/* Filter by Severity */}
            <div className="floating-filters__control">
              <label className="floating-filters__label">Severity</label>
              <select
                className="floating-filters__select"
                value={filters.severity}
                onChange={(e) => handleSelectChange('severity', e.target.value)}
              >
                <option value="all">All Severities</option>
                <option value="critical">Critical (Red)</option>
                <option value="high">High (Orange)</option>
                <option value="medium">Medium (Yellow)</option>
                <option value="low">Low (Green)</option>
              </select>
            </div>

            {/* Filter by District */}
            <div className="floating-filters__control">
              <label className="floating-filters__label">District</label>
              <select
                className="floating-filters__select"
                value={filters.district}
                onChange={(e) => handleSelectChange('district', e.target.value)}
              >
                <option value="all">All Districts</option>
                {allDistricts.map((d) => (
                  <option key={d} value={d}>
                    {d}
                  </option>
                ))}
              </select>
            </div>

            {/* Filter by Maintenance Status */}
            <div className="floating-filters__control">
              <label className="floating-filters__label">Work Status</label>
              <select
                className="floating-filters__select"
                value={filters.status}
                onChange={(e) => handleSelectChange('status', e.target.value)}
              >
                <option value="all">All Statuses</option>
                <option value="pending">Pending</option>
                <option value="in_progress">In Progress</option>
                <option value="completed">Completed</option>
                <option value="scheduled">Scheduled</option>
              </select>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
