import React, {
  ReactNode,
  useState,
  Fragment,
  ChangeEvent,
  MouseEvent,
} from "react";
import { Dialog, Transition } from "@headlessui/react";
import {
  useAccount,
  useContractRead,
  useContractReads,
  useContractWrite,
  usePrepareContractWrite,
} from "wagmi";
import { erc20ABI } from "wagmi";
import ERC20 from "../../out/ERC20.sol/ERC20.json";

const DepositModal = ({
  vault,
  underlying,
}: {
  vault: string;
  underlying: string;
}) => {
  const [isOpen, setIsOpen] = useState(false);
  const [deposit, setDeposit] = useState("");
  const [approveDisabled, setApproveDisabled] = useState(true);
  const [depositDisabled, setDepositDisabled] = useState(true);

  const { address } = useAccount();

  const { data } = useContractReads({
    contracts: [
      {
        addressOrName: underlying,
        contractInterface: ERC20.abi,
        functionName: "allowance",
        args: [address, vault],
      },
      {
        addressOrName: underlying,
        contractInterface: ERC20.abi,
        functionName: "name",
      },
      {
        addressOrName: underlying,
        contractInterface: ERC20.abi,
        functionName: "balanceOf",
        args: address,
      },
    ],
    onSettled(data, error) {
      if (error) console.log("error", error);
      console.log("allownace", data);
    },
  });

  const { config: approvalConfig } = usePrepareContractWrite({
    addressOrName: vault,
    contractInterface: ERC20.abi,
    functionName: "deposit",
    args: [vault, parseInt(deposit)],
  });
  const { write: approvalWrite } = useContractWrite(approvalConfig);

  const { config: depositConfig } = usePrepareContractWrite({
    addressOrName: "underlying",
    contractInterface: ERC20.abi,
    functionName: "",
    args: [deposit, address],
  });
  const { write: depositWrite } = useContractWrite(depositConfig);

  const closeModal = () => {
    setIsOpen(false);
  };

  const openModal = () => {
    const allowance = data?.[0].toString();

    if (allowance && parseInt(allowance) == 0) {
      setApproveDisabled(false);
    }

    setIsOpen(true);
  };

  const handleChange = (e: ChangeEvent<HTMLInputElement>) => {
    const allowance = data?.[0].toString();
    const amount = e.target.value;

    if (allowance && parseInt(allowance) > parseInt(amount)) {
      setDepositDisabled(false);
    }
    setDeposit(amount);
  };

  const handleApproval = (e: MouseEvent<HTMLButtonElement>) => {
    const balance = data?.[2].toString();
    if (balance && parseInt(deposit) > parseInt(balance)) {
      return;
    }

    approvalWrite?.();
  };

  const handleDeposit = (e: MouseEvent<HTMLButtonElement>) => {
    const allowance = data?.[0].toString();
    const balance = data?.[2].toString();
    console.log("allownace", allowance);

    if (
      allowance &&
      balance &&
      parseInt(allowance) < parseInt(deposit) &&
      parseInt(balance) < parseInt(deposit)
    ) {
      return;
    }

    depositWrite?.();
  };

  return (
    <>
      <div className="">
        <button
          className="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-3 rounded"
          onClick={openModal}
        >
          deposit
        </button>
      </div>

      <Transition appear show={isOpen} as={Fragment}>
        <Dialog as="div" className="relative z-10" onClose={closeModal}>
          <Transition.Child
            as={Fragment}
            enter="ease-out duration-300"
            enterFrom="opacity-0"
            enterTo="opacity-100"
            leave="ease-in duration-200"
            leaveFrom="opacity-100"
            leaveTo="opacity-0"
          >
            <div className="fixed inset-0 bg-black bg-opacity-25" />
          </Transition.Child>

          <div className="fixed inset-0 overflow-y-auto">
            <div className="flex min-h-full items-center justify-center p-4 text-center">
              <Transition.Child
                as={Fragment}
                enter="ease-out duration-300"
                enterFrom="opacity-0 scale-95"
                enterTo="opacity-100 scale-100"
                leave="ease-in duration-200"
                leaveFrom="opacity-100 scale-100"
                leaveTo="opacity-0 scale-95"
              >
                <Dialog.Panel className="w-1/3 max-w-md transform overflow-hidden rounded-2xl bg-white p-4 text-left align-middle shadow-xl transition-all">
                  <div className="flex justify-between items-center">
                    <Dialog.Title
                      as="h3"
                      className="text-lg font-medium leading-6 text-gray-900"
                    >
                      Deposit
                    </Dialog.Title>

                    <div className="">
                      <button
                        type="button"
                        className="rounded-md border border-transparent text-xl font-medium text-black hover:bg-blue-200 focus:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2"
                        onClick={closeModal}
                      >
                        X
                      </button>
                    </div>
                  </div>

                  <div>Balance: {data && `${data[2]} ${data[1]}`}</div>

                  <div className="my-8 flex justify-between items-center gap-4">
                    <input
                      className="shadow appearance-none border border-gray-500 w-full rounded py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline"
                      type="text"
                      value={deposit}
                      onChange={handleChange}
                    />

                    <button className="rounded-md border border-black px-2 py-1 border-transparent text-lg font-medium text-black hover:bg-blue-200 focus:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2">
                      Max
                    </button>
                  </div>

                  <div className="flex justify-between items-center gap-3">
                    <button
                      className={`w-full rounded-md border border-black px-2 py-1 border-transparent text-lg font-medium text-black hover:bg-blue-200 focus:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2 ${
                        approveDisabled ? "opacity-50 cursor-not-allowed" : ""
                      }`}
                      disabled={approveDisabled}
                      onClick={handleApproval}
                    >
                      Approve
                    </button>
                    <button
                      className={`w-full rounded-md border border-black px-2 py-1 border-transparent text-lg font-medium text-black hover:bg-blue-200 focus:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2 ${
                        depositDisabled ? "opacity-50 cursor-not-allowed" : ""
                      }`}
                      disabled={depositDisabled}
                      onClick={handleDeposit}
                    >
                      Deposit
                    </button>
                  </div>
                </Dialog.Panel>
              </Transition.Child>
            </div>
          </div>
        </Dialog>
      </Transition>
    </>
  );
};

export default DepositModal;
