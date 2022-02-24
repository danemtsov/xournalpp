#include "MetadataManager.h"

#include <algorithm>  // for sort
#include <cstdlib>    // for strtoll, strtod
#include <fstream>    // for operator<<, basic_ostream, basic_stringb...
#include <memory>     // for allocator_traits<>::value_type
#include <sstream>    // for istringstream
#include <string>     // for char_traits, string, getline, operator!=
#include <tuple>

#include <glib.h>  // for g_get_real_time, g_warning, gint64

#include "util/PathUtil.h"   // for getConfigSubfolder
#include "util/XojMsgBox.h"  // for XojMsgBox

using namespace std;

MetadataEntry::MetadataEntry(): valid(false), zoom(1), page(0), time(0) {}


MetadataManager::MetadataManager(): metadata(nullptr) {}

MetadataManager::~MetadataManager() { documentChanged(); }

/**
 * Delete an old metadata file
 */
void MetadataManager::deleteMetadataFile(fs::path const& path) {
    // be careful, delete the Metadata file, NOT the Document!
    if (path.extension() != ".metadata") {
        g_warning("Try to delete non-metadata file: %s", path.u8string().c_str());
        return;
    }

    try {
        fs::remove(path);
    } catch (const fs::filesystem_error&) {
        g_warning("Could not delete metadata file %s", path.u8string().c_str());
    }
}

/**
 * Document was closed, a new document was opened etc.
 */
void MetadataManager::documentChanged() {
    this->mutex.lock();
    MetadataEntry* m = metadata;
    metadata = nullptr;
    this->mutex.unlock();

    if (m == nullptr) {
        return;
    }

    storeMetadata(m);
    delete m;
}

auto sortMetadata(MetadataEntry& a, MetadataEntry& b) -> bool { return a.time > b.time; }

/**
 * Load the metadata list (sorted)
 */
auto MetadataManager::loadList() -> vector<MetadataEntry> {
    auto folder = Util::getConfigSubfolder("metadata");

    vector<MetadataEntry> data;
    try {
        for (auto const& f: fs::directory_iterator(folder)) {
            MetadataEntry entry = loadMetadataFile(f.path());

            if (entry.valid) {
                data.push_back(entry);
            }
        }
    } catch (const fs::filesystem_error& e) {
        XojMsgBox::showErrorToUser(nullptr, e.what());
        return data;
    }

    std::sort(data.begin(), data.end(), sortMetadata);

    return data;
}

/**
 * Parse a single metadata file
 */
auto MetadataManager::loadMetadataFile(fs::path const& path) -> MetadataEntry {
    MetadataEntry entry;
    entry.metadataFile = path;

    using MetadataErrorTuple = std::tuple<string>;
    try {
        string line;
        ifstream infile(path);

        auto time = path.stem().u8string();
        entry.time = strtoll(time.c_str(), nullptr, 10);

        if (!getline(infile, line) || line != "XOJ-METADATA/1.0") {
            throw MetadataErrorTuple{"invalid header line"};
        }

        if (!getline(infile, line)) {
            throw MetadataErrorTuple{"invalid 2nd line"};
        }
        istringstream iss(line);
        iss >> quoted(line);
        try {
            entry.path = fs::u8path(line);
        } catch (const std::exception& e) {
            throw MetadataErrorTuple{string("Error decoding file path: ") += e.what()};
        }

        if (!getline(infile, line) || line.length() < 6 || line.substr(0, 5) != "page=") {
            throw MetadataErrorTuple{"invalid 3rd line"};
        }
        entry.page = strtoll(line.substr(5).c_str(), nullptr, 10);

        if (!getline(infile, line) || line.length() < 6 || line.substr(0, 5) != "zoom=") {
            throw MetadataErrorTuple{"invalid 4th line"};
        }
        entry.zoom = strtod(line.substr(5).c_str(), nullptr);

        entry.valid = true;

    } catch (const MetadataErrorTuple& e) {
        const auto& [invalidReason] = e;
        g_warning("Invalid metadata file: %s - deleting %s", invalidReason.c_str(), path.u8string().c_str());
        deleteMetadataFile(path);
    }

    return entry;
}

/**
 * Get the metadata for a file
 */
auto MetadataManager::getForFile(fs::path const& file) -> MetadataEntry {
    vector<MetadataEntry> files = loadList();

    MetadataEntry entry;
    for (const MetadataEntry& e: files) {
        if (e.path == file) {
            entry = e;
            break;
        }
    }

    for (int i = 20; i < static_cast<int>(files.size()); i++) {
        auto path = files[i].metadataFile;
        deleteMetadataFile(path);
    }

    return entry;
}

/**
 * Store metadata to file
 */
void MetadataManager::storeMetadata(MetadataEntry* m) {
    vector<MetadataEntry> files = loadList();
    for (const MetadataEntry& e: files) {
        if (e.path == m->path) {
            // This is an old entry with the same path
            deleteMetadataFile(e.metadataFile);
        }
    }

    auto path = Util::getConfigSubfolder("metadata");
    gint64 time = g_get_real_time();
    path /= std::to_string(time);
    path += ".metadata";

    ofstream out(path);
    // TODO (danemtsov) revisit when locale issues are resolved (xournalpp/#3611)
    out.imbue(locale::classic());
    out << "XOJ-METADATA/1.0\n";
    out << quoted(m->path.u8string()) << "\n";
    out << "page=" << m->page << "\n";
    out << "zoom=" << m->zoom << "\n";
    out.close();
}

/**
 * Store the current data into metadata
 */
void MetadataManager::storeMetadata(fs::path const& file, int page, double zoom) {
    if (file.empty()) {
        return;
    }

    this->mutex.lock();
    if (metadata == nullptr) {
        metadata = new MetadataEntry();
    }

    metadata->valid = true;
    metadata->path = file;
    metadata->zoom = zoom;
    metadata->page = page;
    metadata->time = g_get_real_time();
    this->mutex.unlock();
}
