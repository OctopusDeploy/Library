"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (Object.hasOwnProperty.call(mod, k)) result[k] = mod[k];
    result["default"] = mod;
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
const core = __importStar(require("@actions/core"));
const github = __importStar(require("@actions/github"));
function run() {
    var _a;
    return __awaiter(this, void 0, void 0, function* () {
        try {
            const milestone = core.getInput('milestone', { required: true });
            const prNumber = getPrNumber();
            if (!prNumber) {
                console.log('Could not get pull request number from context, exiting');
                return;
            }
            const client = new github.GitHub(process.env.GITHUB_TOKEN || "");
            core.debug('fetching milestone to assign to pull request');
            const milestones = yield client.issues.listMilestonesForRepo({
                owner: github.context.repo.owner,
                repo: github.context.repo.repo
            });
            const milestoneToAssign = milestones.data.find(m => m.title === milestone);
            if (!milestoneToAssign) {
                console.log('Could not get milestone to assign to pull request, exiting');
                return;
            }
            yield addMilestone(client, prNumber, (_a = milestoneToAssign) === null || _a === void 0 ? void 0 : _a.number);
        }
        catch (error) {
            core.error(error);
            core.setFailed(error.message);
        }
    });
}
function getPrNumber() {
    const pullRequest = github.context.payload.pull_request;
    if (!pullRequest) {
        return undefined;
    }
    return pullRequest.number;
}
function addMilestone(client, prNumber, milestoneNumber) {
    return __awaiter(this, void 0, void 0, function* () {
        yield client.issues.update({
            owner: github.context.repo.owner,
            repo: github.context.repo.repo,
            issue_number: prNumber,
            milestone: milestoneNumber
        });
    });
}
run();
